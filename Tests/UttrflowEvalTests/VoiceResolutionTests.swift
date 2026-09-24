// Tests that a requested synthesizer voice is checked against what `say` actually has installed.
import Testing

@testable import UttrflowEval

private struct FakeVoiceCatalogueForResolution: VoiceCatalogue {
    let names: Set<String>
    func installedVoiceNames() -> Set<String> { names }
}

@Suite("Resolving a requested voice")
struct VoiceResolutionTests {
    @Test("an installed voice resolves to itself")
    func installedVoiceResolvesToItself() {
        let resolved = resolveVoice(
            requested: "Samantha", catalogue: FakeVoiceCatalogueForResolution(names: ["Alex", "Samantha"]))
        #expect(resolved.installed == "Samantha")
        #expect(resolved.label == "Samantha")
    }

    @Test("a name absent from `say -v ?` falls back to the system default, not a false success")
    func unavailableVoiceFallsBackToSystemDefault() {
        let resolved = resolveVoice(
            requested: "DefinitelyNotAnInstalledVoice",
            catalogue: FakeVoiceCatalogueForResolution(names: ["Alex", "Samantha"]))
        #expect(resolved.installed == nil)
        #expect(resolved.label.contains("system default"))
        #expect(resolved.label.contains("DefinitelyNotAnInstalledVoice"))
    }

    @Test("an empty catalogue never claims a voice is installed")
    func emptyCatalogueNeverClaimsAVoiceIsInstalled() {
        let resolved = resolveVoice(
            requested: "Samantha", catalogue: FakeVoiceCatalogueForResolution(names: []))
        #expect(resolved.installed == nil)
    }

    @Test("the label is what distinguishes cache entries, and it differs between outcomes")
    func labelDiffersBetweenInstalledAndFallback() {
        let installed = resolveVoice(
            requested: "Samantha", catalogue: FakeVoiceCatalogueForResolution(names: ["Samantha"]))
        let fallback = resolveVoice(
            requested: "Samantha", catalogue: FakeVoiceCatalogueForResolution(names: []))
        #expect(installed.label != fallback.label)
    }
}
