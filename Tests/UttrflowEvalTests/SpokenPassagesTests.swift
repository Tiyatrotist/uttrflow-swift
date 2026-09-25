// Tests that SpokenPassages resolves and caches against the voice that actually spoke.
import Foundation
import Testing
import UttrflowAudio

@testable import UttrflowEval

private struct FakeVoiceCatalogueForSpokenPassages: VoiceCatalogue {
    let names: Set<String>
    func installedVoiceNames() -> Set<String> { names }
}

/// Records every synthesis call instead of shelling out to `say`, and writes real WAV bytes back.
private final class RecordingSynthesizer: VoiceSynthesizer, @unchecked Sendable {
    private(set) var calls: [(text: String, voice: String?)] = []

    func speak(_ text: String, voice: String?, to destination: URL) -> Bool {
        calls.append((text, voice))
        let samples: [Float] = Array(repeating: 0.1, count: 1_600)
        return (try? WAVEncoder.encode(.canonical(samples)).write(to: destination)) != nil
    }
}

@Suite("Speaking and caching a profile's passages")
struct SpokenPassagesTests {
    private struct Sandbox: ~Copyable {
        let directory: URL
        init() {
            directory = URL(fileURLWithPath: NSTemporaryDirectory())
                .appending(path: "uttrflow-spoken-passages-\(UUID().uuidString)")
        }
        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    private let passages = [ProfilePassage(length: .short, text: "hello there")]

    @Test("an installed voice is passed straight to the synthesizer")
    func installedVoiceIsUsedDirectly() throws {
        let sandbox = Sandbox()
        let synthesizer = RecordingSynthesizer()
        let (spoken, resolved) = try SpokenPassages(
            directory: sandbox.directory, voice: "Samantha",
            catalogue: FakeVoiceCatalogueForSpokenPassages(names: ["Samantha"]), synthesizer: synthesizer
        ).prepare(passages)

        #expect(spoken.count == 1)
        #expect(resolved.installed == "Samantha")
        #expect(synthesizer.calls.map(\.voice) == ["Samantha"])
    }

    @Test("a voice `say -v ?` never lists falls back rather than being trusted")
    func unavailableVoiceFallsBackAndIsReported() throws {
        let sandbox = Sandbox()
        let synthesizer = RecordingSynthesizer()
        let (spoken, resolved) = try SpokenPassages(
            directory: sandbox.directory, voice: "DefinitelyNotAnInstalledVoice",
            catalogue: FakeVoiceCatalogueForSpokenPassages(names: ["Samantha"]), synthesizer: synthesizer
        ).prepare(passages)

        #expect(spoken.count == 1)
        #expect(resolved.installed == nil)
        #expect(resolved.label.contains("DefinitelyNotAnInstalledVoice"))
        // `voice: nil` tells the synthesizer to use the system default, never the unavailable name.
        #expect(synthesizer.calls.map(\.voice) == [nil])
    }

    @Test("an unchanged voice and text are not re-synthesised")
    func unchangedInputsHitTheCache() throws {
        let sandbox = Sandbox()
        let synthesizer = RecordingSynthesizer()
        let spokenPassages = SpokenPassages(
            directory: sandbox.directory, voice: "Samantha",
            catalogue: FakeVoiceCatalogueForSpokenPassages(names: ["Samantha"]), synthesizer: synthesizer)

        _ = try spokenPassages.prepare(passages)
        _ = try spokenPassages.prepare(passages)

        #expect(synthesizer.calls.count == 1)
    }

    @Test("the cache is keyed on the resolved voice, not the requested name")
    func cacheInvalidatesWhenTheEffectiveVoiceChanges() throws {
        let sandbox = Sandbox()
        let synthesizer = RecordingSynthesizer()

        // First run: "Samantha" is not installed, so the system default speaks.
        let (_, firstResolved) = try SpokenPassages(
            directory: sandbox.directory, voice: "Samantha",
            catalogue: FakeVoiceCatalogueForSpokenPassages(names: []), synthesizer: synthesizer
        ).prepare(passages)
        #expect(firstResolved.installed == nil)
        #expect(synthesizer.calls.count == 1)

        // Second run: the same requested name is now genuinely installed, so the fallback audio must not stick.
        let (_, secondResolved) = try SpokenPassages(
            directory: sandbox.directory, voice: "Samantha",
            catalogue: FakeVoiceCatalogueForSpokenPassages(names: ["Samantha"]), synthesizer: synthesizer
        ).prepare(passages)
        #expect(secondResolved.installed == "Samantha")
        #expect(synthesizer.calls.count == 2)
        #expect(synthesizer.calls.last?.voice == "Samantha")
    }

    @Test("changed passage text is re-synthesised even when the voice is unchanged")
    func cacheInvalidatesWhenTextChanges() throws {
        let sandbox = Sandbox()
        let synthesizer = RecordingSynthesizer()
        let catalogue = FakeVoiceCatalogueForSpokenPassages(names: ["Samantha"])

        _ = try SpokenPassages(
            directory: sandbox.directory, voice: "Samantha", catalogue: catalogue,
            synthesizer: synthesizer
        ).prepare(passages)
        #expect(synthesizer.calls.count == 1)

        let changed = [ProfilePassage(length: .short, text: "a different sentence")]
        _ = try SpokenPassages(
            directory: sandbox.directory, voice: "Samantha", catalogue: catalogue,
            synthesizer: synthesizer
        ).prepare(changed)
        #expect(synthesizer.calls.count == 2)
    }
}
