// Tests that a refused main-window change keeps the failure's own sentence and is drawn by what it cost.
import UttrflowCore
import Testing

@testable import UttrflowUX

@Suite("What the main window says when a change is refused")
struct MainNoticeTests {
    /// The store already writes the sentence, so the page must not word the same refusal a second way.
    @Test("a store's refusal is said in the store's own words")
    func keepsTheStoresSentence() {
        #expect(
            MainNotice(refusing: HistoryStoreError.couldNotWrite).message
                == HistoryStoreError.couldNotWrite.userMessage)
        #expect(
            MainNotice(refusing: SnippetStoreError.couldNotWrite).message
                == SnippetStoreError.couldNotWrite.userMessage)
        #expect(
            MainNotice(refusing: DictionaryStoreError.couldNotWrite).message
                == DictionaryStoreError.couldNotWrite.userMessage)
    }

    /// A lost write costs the user something, so it is drawn as a fault rather than as a caption.
    @Test("a lost write is drawn as something that went wrong")
    func drawsALostWriteAsAFault() {
        let notice = MainNotice(refusing: HistoryStoreError.couldNotWrite)
        #expect(notice.tone == .critical)
        #expect(notice.symbolName == "exclamationmark.triangle")
    }

    /// An error nobody typed still has to reach the screen, and never as a type name.
    @Test("an unforeseen error is said plainly and offers another attempt")
    func describesAnUnforeseenError() {
        struct Nameless: Error {}
        let notice = MainNotice(refusing: Nameless())
        #expect(notice.message == MainNotice.unforeseenMessage)
        #expect(notice.tone == .warning)
        #expect(notice.symbolName == "arrow.clockwise")
    }

    /// Every severity draws, so a refusal added later cannot inherit a tone nobody chose.
    @Test("each cost the user can be put to has a tone and a symbol of its own")
    func drawsEverySeverity() {
        let drawings = FailureSeverity.allCases.map { MainNotice.drawing(for: $0) }
        #expect(drawings.map(\.tone) == [.critical, .critical, .warning, .neutral])
        #expect(!drawings.contains { $0.symbolName.isEmpty })
    }

    @Test("a notice built from its parts keeps them")
    func keepsItsParts() {
        let notice = MainNotice(message: "No.", symbolName: "xmark", tone: .good)
        #expect(notice.message == "No.")
        #expect(notice.symbolName == "xmark")
        #expect(notice.tone == .good)
    }
}
