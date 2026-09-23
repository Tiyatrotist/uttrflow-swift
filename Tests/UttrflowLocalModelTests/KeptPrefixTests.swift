import Testing

@testable import UttrflowLocalModel

@Suite("Reading the last pass's prompt again as far as the two share")
struct KeptPrefixTests {
    /// How many opening tokens the warm instructions already hold, which reuse has to beat to be worth anything.
    private let warmed = 4

    @Test("Consecutive keystrokes share every token but the ones the typed line added.")
    func aKeystrokeSharesAllButItsOwnTokens() {
        let read = [1, 2, 3, 4, 5, 6, 7, 8]
        let all = [1, 2, 3, 4, 5, 6, 7, 9, 10]
        #expect(MLXCandidateScorer.sharedPrefix(of: read, and: all, beating: warmed) == 7)
    }

    @Test("A prompt sharing no more than the warmed instructions is read from those instead.")
    func sharingOnlyTheInstructionsIsNoReuse() {
        let read = [1, 2, 3, 4, 5, 6]
        #expect(MLXCandidateScorer.sharedPrefix(of: read, and: [1, 2, 3, 4, 7], beating: warmed) == nil)
        #expect(MLXCandidateScorer.sharedPrefix(of: read, and: [1, 2, 3, 9], beating: warmed) == nil)
        #expect(MLXCandidateScorer.sharedPrefix(of: [], and: [1, 2, 3, 4, 5, 6], beating: 0) == nil)
        #expect(MLXCandidateScorer.sharedPrefix(of: read, and: [], beating: 0) == nil)
    }

    @Test(
        "A prompt the cache already holds whole keeps its last token back, since the model answers from it.")
    func theLastTokenIsAlwaysRead() {
        let read = [1, 2, 3, 4, 5, 6, 7]
        #expect(MLXCandidateScorer.sharedPrefix(of: read, and: read, beating: warmed) == 6)
        #expect(MLXCandidateScorer.sharedPrefix(of: read + [8], and: read, beating: warmed) == 6)
        #expect(
            MLXCandidateScorer.sharedPrefix(of: [1, 2, 3, 4, 5], and: [1, 2, 3, 4, 5], beating: warmed) == nil
        )
    }

    @Test("A token that changed inside the shared run ends it, however much matches after.")
    func aChangeInsideTheRunEndsIt() {
        let read = [1, 2, 3, 4, 5, 6, 7, 8]
        #expect(MLXCandidateScorer.sharedPrefix(of: read, and: [1, 2, 3, 4, 9, 6, 7, 8], beating: 3) == 4)
        #expect(
            MLXCandidateScorer.sharedPrefix(of: read, and: [1, 2, 3, 4, 9, 6, 7, 8], beating: warmed) == nil)
    }
}
