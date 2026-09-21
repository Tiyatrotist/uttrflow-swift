// Recovers the audio after a decode that stopped because the decoder ran out of positions.
public import UttrflowCore

/// Calls a recogniser, then calls it again on whatever audio the first call did not cover, until it stops hitting the cap.
public enum CappedDecodeRetry {
    /// The most retries, so a decode that cannot make progress gives up rather than spinning.
    public static let maxRetries = 10
    /// A token count past which a decode is treated as having stopped because the decoder ran out of positions, not at an end-of-text token. WhisperKit's 223-position shared decode budget leaves room for about 47 Hindi words or 200+ English ones, so this catches Hindi without firing on English.
    public static let tokenCapThreshold = 215
    /// A word longer than this is taken to be the fragment the recogniser stretched to fill the rest of the audio after the decoder stopped mid-word; the previous word's end is where the real decode stopped.
    public static let fragmentWordDuration: Duration = .milliseconds(900)

    /// Decodes `samples` with `backend`, retrying the tail when the decoder's token cap stops a decode early.
    public static func transcribe(
        samples: [Float],
        sampleRate: Double = Double(AudioSamples.canonicalSampleRate),
        languageHint: LanguageCode?,
        vocabulary: [String],
        using backend: any TranscriptionBackend
    ) async throws(SpeechEngineError) -> RawTranscript {
        var accumulatedText = ""
        var accumulatedSegments: [RawSegment] = []
        var languageIdentifier: String?
        var languageProbability: Double?
        var totalEffort = DecodeEffort.none
        var totalTokensUsed = 0
        var remaining = samples
        var sliceStartSeconds = 0.0

        for _ in 0..<maxRetries {
            guard !remaining.isEmpty else { break }
            let result = try await backend.transcribe(
                remaining, languageHint: languageHint, biasedTowards: vocabulary)
            languageIdentifier = result.languageIdentifier ?? languageIdentifier
            languageProbability = result.languageProbability ?? languageProbability
            totalEffort = totalEffort.adding(result.effort)
            totalTokensUsed += result.tokensUsed

            if !result.text.isEmpty {
                accumulatedText += (accumulatedText.isEmpty ? "" : " ") + result.text
            }
            let shifted = result.segments.map { segment in
                RawSegment(
                    text: segment.text,
                    start: segment.start + sliceStartSeconds,
                    end: segment.end + sliceStartSeconds,
                    words: segment.words?.map { word in
                        RawWord(
                            text: word.text,
                            start: word.start + sliceStartSeconds,
                            end: word.end + sliceStartSeconds,
                            probability: word.probability)
                    })
            }
            accumulatedSegments.append(contentsOf: shifted)

            // The decoder reports its consumed positions: once that passes the cap, more words are still in the audio.
            let sliceDuration = Duration.seconds(Double(remaining.count) / sampleRate)
            // The token count is the reliable signal — a recogniser that reports it has run out of room at ~223 positions. A backend that does not report tokens falls back to the segment-end heuristic.
            let hitCap =
                result.tokensUsed > 0
                ? result.tokensUsed >= tokenCapThreshold
                : result.appearsCapped(audioDuration: sliceDuration)
            guard hitCap else { break }
            // The recogniser may stretch the final fragment word to the audio end; trust the last *normal* word as where it actually stopped.
            guard let cutoff = cappedCutoffSeconds(in: result.segments) else { break }
            let consumedSamples = Int((cutoff * sampleRate).rounded(.down))
            guard consumedSamples > 0, consumedSamples < remaining.count else { break }
            remaining = Array(remaining[consumedSamples...])
            sliceStartSeconds += cutoff
        }

        return RawTranscript(
            text: accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines),
            languageIdentifier: languageIdentifier,
            languageProbability: languageProbability,
            segments: accumulatedSegments,
            effort: totalEffort,
            tokensUsed: totalTokensUsed
        )
    }

    /// Where in the recogniser's view the decoder actually stopped, in seconds from the start of the slice, ignoring any final fragment word it stretched past the cap.
    fileprivate static func cappedCutoffSeconds(in segments: [RawSegment]) -> Double? {
        // Walk newest-to-oldest so the first non-fragment found is the chronologically last word the recogniser finished, not the first.
        let allWords = segments.reversed().flatMap { ($0.words ?? []).reversed() }
        guard !allWords.isEmpty else {
            return segments.last?.end
        }
        let fragmentSeconds = fragmentWordDuration.inSeconds
        for word in allWords {
            let duration = word.end - word.start
            guard duration <= fragmentSeconds else { continue }
            return word.end
        }
        return segments.last?.end
    }
}
