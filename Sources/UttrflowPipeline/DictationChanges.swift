// Every change the pipeline makes to what the user said, in a form it can show and undo.
public import struct Foundation.UUID

/// One word Uttrflow replaced, with everything an undo needs on the value. See Docs/pipeline-changes.md.
public struct DictationCorrection: Sendable, Equatable {
    /// Exactly what the recogniser produced, verbatim.
    public let heard: String
    /// What was written in its place.
    public let wrote: String
    /// Which spoken words this covered, as indices into the transcript's words.
    public let wordRange: Range<Int>
    /// The dictionary entry that won, which `recordUse(of:)` and `recordRevert(of:)` both take.
    public let entryID: UUID
    /// Why, in the proposing engine's own words; a string because the pipeline must not reinterpret it.
    public let reason: String
    /// What the recogniser scored the replaced words, so a sceptic can see the engine only moved on a guess.
    public let heardConfidence: Double

    public init(
        heard: String, wrote: String, wordRange: Range<Int>, entryID: UUID, reason: String,
        heardConfidence: Double
    ) {
        self.heard = heard
        self.wrote = wrote
        self.wordRange = wordRange
        self.entryID = entryID
        self.reason = reason
        self.heardConfidence = heardConfidence
    }
}

extension DictationCorrection {
    /// Splices every correction in by character range at once, dropping any with a bad or overlapping range.
    public static func applying(
        _ corrections: [DictationCorrection], to text: String
    ) -> CorrectedTranscript {
        let words = text.spokenWordRanges()
        var result = ""
        var applied: [DictationCorrection] = []
        var copiedUpTo = text.startIndex

        for correction in corrections.sorted(by: { $0.wordRange.lowerBound < $1.wordRange.lowerBound }) {
            let wanted = correction.wordRange
            guard wanted.lowerBound >= 0, wanted.upperBound <= words.count, !wanted.isEmpty
            else { continue }
            let span = words[wanted.lowerBound].lowerBound..<words[wanted.upperBound - 1].upperBound
            guard span.lowerBound >= copiedUpTo else { continue }

            // The recogniser hangs punctuation on the word, so only the word inside the token is replaced.
            let opening = SpokenToken(text[words[wanted.lowerBound]]).leading
            let closing = SpokenToken(text[words[wanted.upperBound - 1]]).trailing
            let written = String(opening) + correction.wrote + closing

            result += text[copiedUpTo..<span.lowerBound]
            result += written
            // An undo looks for what was written, punctuation and all, not for what was proposed.
            applied.append(correction.written(as: written))
            copiedUpTo = span.upperBound
        }
        result += text[copiedUpTo...]
        return CorrectedTranscript(text: result, corrections: applied)
    }

    /// A copy naming exactly what was written in the transcript, which is what an undo has to match.
    private func written(as text: String) -> Self {
        Self(
            heard: heard, wrote: text, wordRange: wordRange, entryID: entryID, reason: reason,
            heardConfidence: heardConfidence)
    }
}

extension String {
    /// The whitespace-separated words, which every ``DictationCorrection/wordRange`` indexes into.
    var spokenWords: [Substring] { split(whereSeparator: \.isWhitespace) }

    /// Where each whitespace-separated word begins and ends, the split a correction's range indexes into.
    fileprivate func spokenWordRanges() -> [Range<String.Index>] {
        spokenWords.map { $0.startIndex..<$0.endIndex }
    }
}

/// One spoken token with the punctuation the recogniser attached to it held apart from the word itself.
struct SpokenToken {
    /// The punctuation before the word: an opening quote or bracket. A word with none is the usual case.
    let leading: Substring
    /// The word itself, empty when the token is punctuation through and through and so names no word.
    let core: Substring
    /// The punctuation after the word: a comma, a full stop, a question mark.
    let trailing: Substring

    init(_ token: Substring) {
        var start = token.startIndex
        var end = token.endIndex
        while start < end, token[start].isPunctuation { token.formIndex(after: &start) }
        while end > start, token[token.index(before: end)].isPunctuation {
            token.formIndex(before: &end)
        }
        leading = token[..<start]
        core = token[start..<end]
        trailing = token[end...]
    }

    init(_ token: String) { self.init(token[...]) }

    /// How both sides of a score lookup name this word: the word alone, lower-cased, empty for punctuation.
    var scoreKey: String { core.lowercased() }
}

/// A transcript after the user's own dictionary has had its say.
public struct CorrectedTranscript: Sendable, Equatable {
    /// The words to carry on with.
    public let text: String
    /// Every change made, in spoken order; empty is the expected and commonest answer.
    public let corrections: [DictationCorrection]

    public init(text: String, corrections: [DictationCorrection] = []) {
        self.text = text
        self.corrections = corrections
    }

    /// A transcript nothing was done to.
    public static func unchanged(_ text: String) -> Self { Self(text: text) }
}

/// One snippet firing once.
public struct SnippetUse: Sendable, Equatable {
    /// Which snippet fired, as an id, since the store may have changed by the time this is read.
    public let snippetID: UUID
    /// The replaced words exactly as they appeared in the transcript, not the stored trigger.
    public let matched: String
    /// What replaced them.
    public let expansion: String

    public init(snippetID: UUID, matched: String, expansion: String) {
        self.snippetID = snippetID
        self.matched = matched
        self.expansion = expansion
    }
}

/// A transcript after the user's snippets have had theirs.
public struct ExpandedTranscript: Sendable, Equatable {
    /// The text to insert.
    public let text: String
    /// Every firing, in the order they appear. A snippet that fired twice appears twice.
    public let snippets: [SnippetUse]

    public init(text: String, snippets: [SnippetUse] = []) {
        self.text = text
        self.snippets = snippets
    }

    /// A transcript nothing was done to.
    public static func unchanged(_ text: String) -> Self { Self(text: text) }
}

/// The dictionary corrections and snippet firings shown, offered for undo, and learnt from together.
public struct AppliedChanges: Sendable, Equatable {
    public let corrections: [DictationCorrection]
    public let snippets: [SnippetUse]
    /// Dictionary entries whose spelling the tidier wrote for a doubtful run: counted used like a correction's, not yet undoable.
    public let entriesTaken: [UUID]
    /// Words the recogniser heard before any rewrite; the space ``DictationCorrection/wordRange`` indexes.
    public let spokenWords: Int?

    public init(
        corrections: [DictationCorrection] = [], snippets: [SnippetUse] = [],
        entriesTaken: [UUID] = [], spokenWords: Int? = nil
    ) {
        self.corrections = corrections
        self.snippets = snippets
        self.entriesTaken = entriesTaken
        self.spokenWords = spokenWords
    }

    /// A dictation that comes out exactly as said, which is what every caller gets without asking.
    public static let none = AppliedChanges()

    /// Whether there is anything to show, undo or learn from; read to skip the learner entirely.
    public var isEmpty: Bool { corrections.isEmpty && snippets.isEmpty && entriesTaken.isEmpty }
}
