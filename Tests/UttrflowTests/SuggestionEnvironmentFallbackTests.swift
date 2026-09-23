// Tests that the coordinator's machine fallback answers only for terminals (#1318).

import Foundation
import Testing
import UttrflowPredict

@testable import Uttrflow

@MainActor
@Suite("The machine fallback answers only for terminals")
struct SuggestionEnvironmentFallbackTests {
    @Test(
        "An empty corpus falls back to the machine in a terminal and to nothing in an editor on the same folder"
    )
    func fallbackIsTerminalOnly() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "uttrflow-1318-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data().write(to: folder.appending(path: "notes.txt"))
        let container = folder.appending(path: "container")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let coordinator = try SuggestionCoordinator(
            container: container, preferences: SuggestionPreferences(isEnabled: true))
        let scope = folder.path(percentEncoded: false)
        let shell = Surface(bundleIdentifier: "com.apple.Terminal", role: "AXTextArea", scope: scope)
        let editor = Surface(bundleIdentifier: "com.apple.dt.Xcode", role: "AXTextArea", scope: scope)

        // The first ask only starts the read, so the terminal is asked until the machine has answered.
        var offered: [String] = []
        for _ in 0..<100 where offered.isEmpty {
            offered = await coordinator.candidates(
                for: SuggestionQuery(surface: shell, typed: "cat no", generation: 1)
            ).map(\.text)
            if offered.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        }
        #expect(offered == ["cat notes.txt"])

        // The folder's listing is now held, so an empty answer here is the gate and not a read still pending.
        let inEditor = await coordinator.candidates(
            for: SuggestionQuery(surface: editor, typed: "cat no", generation: 2))
        #expect(inEditor.isEmpty)
    }
}
