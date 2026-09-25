// Guards the corpus cases where a hostile instruction sits in `selectedText`, not in the dictation.
import UttrflowCore
import Testing

@testable import UttrflowEval

/// Keeps hostile-selected-text coverage from silently shrinking. See Docs/ai-context-line.md.
@Suite("Hostile selected-text cases")
struct HostileSelectedTextCorpusTests {
    private var hostile: [EvaluationCase] { EvaluationCorpus.hostileSelectedText }

    @Test("keeps at least one case per documented hostile screen instruction")
    func coversEveryDocumentedInstruction() {
        #expect(hostile.count >= 3, "found \(hostile.count) hostile-selected-text cases")
    }

    @Test("puts the hostile text only in the selection, never in the spoken words")
    func hostileTextStaysOnScreen() {
        for testCase in hostile {
            let selection = testCase.context.selectedText ?? ""
            #expect(!selection.isEmpty, "\(testCase.id) has no selected text to be hostile")
            for forbidden in testCase.mustNotAdd {
                #expect(
                    !testCase.spoken.lowercased().contains(forbidden.lowercased()),
                    "\(testCase.id) speaks the guarded word, so obeying it would not be a context failure")
            }
        }
    }

    @Test("guards against the output obeying, answering, or copying the screen text")
    func guardsAreNotEmpty() {
        for testCase in hostile {
            #expect(!testCase.mustNotAdd.isEmpty, "\(testCase.id) has nothing to catch a hostile answer")
        }
    }

    /// A reference that trips its own guards would fail every model on a fault in the corpus.
    @Test("accepts each reference answer as a perfect answer to its own case")
    func referencesAreSelfConsistent() {
        for testCase in hostile {
            let score = Scorer.score(testCase.expected, against: testCase)
            #expect(score.similarity == 1, "\(testCase.id) does not match itself")
            #expect(score.invented.isEmpty, "\(testCase.id) breaks its own guard: \(score.invented)")
        }
    }

    /// Withholding context removes the hostile text along with everything else, so the control must be clean.
    @Test("has a context-withheld control that needs no guard to pass")
    func controlWithheldContextIsClean() {
        for testCase in hostile {
            let withheld = testCase.transformationRequest(withholdingContext: true)
            #expect(withheld.context.selectedText == nil, "\(testCase.id) still carries a selection withheld")
            let score = Scorer.score(testCase.expected, against: testCase)
            #expect(score.invented.isEmpty, "\(testCase.id) would fail its own control")
        }
    }
}
