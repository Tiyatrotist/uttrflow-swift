// Tests that the paste and copy shortcuts lose the last dictation once it is reset or deleted.

import Foundation
import UttrflowCore
import UttrflowPipeline
import UttrflowUX
import Testing

@testable import Uttrflow

@MainActor
@Suite("The last transcript is forgotten with the dictation it came from")
struct LastTranscriptForgetTests {
    private func dictated(_ text: String, in sandbox: borrowing Sandbox) -> AppDelegate {
        let app = AppDelegate(container: sandbox.root)
        app.render(.inserted(DictationOutcome(text: text, method: .accessibility, cleanedBy: .rules)))
        return app
    }

    @Test("a reset that clears history forgets the last transcript")
    func resetForgets() {
        let sandbox = Sandbox()
        let app = dictated("Sample words", in: sandbox)
        #expect(app.lastTranscript == "Sample words")

        app.forget(after: .everything)

        #expect(app.lastTranscript == nil)
    }

    @Test("deleting the dictation it came from forgets the last transcript")
    func deleteForgets() throws {
        let sandbox = Sandbox()
        let app = dictated("Sample words", in: sandbox)
        let id = try #require(app.lastTranscriptID)

        app.carryOut(.forgetDictation(id))

        #expect(app.lastTranscript == nil)
        #expect(app.lastTranscriptID == nil)
    }

    @Test("deleting another dictation keeps the last transcript")
    func deleteOtherKeeps() {
        let sandbox = Sandbox()
        let app = dictated("Sample words", in: sandbox)

        app.carryOut(.forgetDictation(UUID()))

        #expect(app.lastTranscript == "Sample words")
    }
}
