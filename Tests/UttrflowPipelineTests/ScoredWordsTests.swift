// Tests how a recogniser's word scores become correction candidates.
import UttrflowCore
import Testing

@testable import UttrflowPipeline

/// Correction only touches a word the recogniser was unsure of, so a wrong score here breaks the feature.
@Suite("What the recogniser was sure of")
struct ScoredWordsTests {
    private func transcription(_ text: String, words: [TranscribedWord]) -> Transcription {
        Transcription(
            text: text,
            segments: [
                TranscriptionSegment(text: text, start: .zero, end: .seconds(1), words: words)
            ])
    }

    @Test("scores each spoken word from what the recogniser reported")
    func scoresWords() {
        let scored = transcription(
            "send it to Nikhil",
            words: [
                TranscribedWord(text: "send", confidence: 0.99),
                TranscribedWord(text: "it", confidence: 0.98),
                TranscribedWord(text: "to", confidence: 0.97),
                TranscribedWord(text: "Nikhil", confidence: 0.41),
            ]
        ).scoredWords

        #expect(scored?.map(\.text) == ["send", "it", "to", "Nikhil"])
        #expect(scored?.last?.confidence == 0.41)
    }

    /// `nil` means nobody measured, which Apple's recogniser produces, and never "everything is certain".
    @Test("declines to judge when nothing was scored")
    func nothingScored() {
        #expect(transcription("send it to Nikhil", words: []).scoredWords == nil)
        #expect(transcription("", words: []).scoredWords == nil)
    }

    /// One is "no reason to doubt it", which keeps an unscored word out of reach of the first condition.
    @Test("leaves an unscored word beyond suspicion rather than guessing")
    func unscoredWord() {
        let scored = transcription(
            "send it onwards",
            words: [TranscribedWord(text: "send", confidence: 0.4)]
        ).scoredWords

        #expect(scored?.first?.confidence == 0.4)
        #expect(scored?.last?.confidence == 1)
    }

    /// The doubtful reading is the one worth acting on.
    @Test("takes the lowest score when a word is heard more than once")
    func repeatedWord() {
        let scored = transcription(
            "Nikhil and Nikhil",
            words: [
                TranscribedWord(text: "Nikhil", confidence: 0.95),
                TranscribedWord(text: "and", confidence: 0.99),
                TranscribedWord(text: "Nikhil", confidence: 0.32),
            ]
        ).scoredWords

        #expect(scored?.first?.confidence == 0.32)
        #expect(scored?.last?.confidence == 0.32)
    }

    /// The recogniser merges punctuation into the word timing it belongs to, so both sides wear it.
    @Test("matches a word through the punctuation the recogniser attached to it")
    func punctuation() {
        let scored = transcription(
            "Thanks, Nikhil.",
            words: [
                TranscribedWord(text: "Thanks,", confidence: 0.99),
                TranscribedWord(text: "Nikhil.", confidence: 0.38),
            ]
        ).scoredWords

        #expect(scored?.count == 2)
        #expect(scored?.last?.confidence == 0.38, "the full stop must not hide the score")
    }

    /// The recogniser opens a word too, and a word behind a quote or a bracket is the same word.
    @Test("matches a word the recogniser opened with a quote or a bracket")
    func openingPunctuation() {
        let scored = transcription(
            "Ask (Nikhil) about \u{201C}Nikhil\u{201D}",
            words: [
                TranscribedWord(text: "Ask", confidence: 0.99),
                TranscribedWord(text: "(Nikhil)", confidence: 0.37),
                TranscribedWord(text: "about", confidence: 0.99),
                TranscribedWord(text: "\u{201C}Nikhil\u{201D}", confidence: 0.44),
            ]
        ).scoredWords

        #expect(scored?.map(\.confidence) == [0.99, 0.37, 0.99, 0.37])
    }

    /// A word keyed with its comma would sit under a key nothing in the transcript can spell.
    @Test("finds the score of a word the transcript carries a comma on")
    func punctuatedWordKeepsItsScore() {
        let scored = transcription(
            "Open the tarvock, then check tarvock.",
            words: [
                TranscribedWord(text: "Open", confidence: 0.99),
                TranscribedWord(text: "the", confidence: 0.99),
                TranscribedWord(text: "tarvock,", confidence: 0.2),
                TranscribedWord(text: "then", confidence: 0.99),
                TranscribedWord(text: "check", confidence: 0.99),
                TranscribedWord(text: "tarvock.", confidence: 0.3),
            ]
        ).scoredWords

        #expect(scored?.map(\.confidence) == [0.99, 0.99, 0.2, 0.99, 0.99, 0.2])
    }

    /// A token that is punctuation and nothing else names no word, so it borrows no word's doubt.
    @Test("leaves a token that is only punctuation beyond suspicion")
    func punctuationOnlyToken() {
        let scored = transcription(
            "well - maybe",
            words: [
                TranscribedWord(text: "well", confidence: 0.99),
                TranscribedWord(text: "-", confidence: 0.1),
                TranscribedWord(text: "maybe", confidence: 0.99),
            ]
        ).scoredWords

        #expect(scored?.map(\.confidence) == [0.99, 1, 0.99])
    }

    /// Case is the recogniser's guess, not the speaker's.
    @Test("matches regardless of how the recogniser capitalised it")
    func caseInsensitive() {
        let scored = transcription(
            "Send it",
            words: [
                TranscribedWord(text: "send", confidence: 0.44),
                TranscribedWord(text: "IT", confidence: 0.5),
            ]
        ).scoredWords

        #expect(scored?.map(\.confidence) == [0.44, 0.5])
    }

    /// One entry per spoken word in order is what a correction's range indexes.
    @Test("returns one score per spoken word, in order")
    func onePerWord() {
        let text = "one two three four five"
        let scored = transcription(
            text, words: [TranscribedWord(text: "three", confidence: 0.2)]
        ).scoredWords

        #expect(scored?.count == text.split(separator: " ").count)
        #expect(scored?[2].confidence == 0.2)
    }
}
