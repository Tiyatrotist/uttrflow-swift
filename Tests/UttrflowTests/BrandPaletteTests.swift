// Tests for the brand palette.

import Foundation
import Testing

@testable import Uttrflow

@Suite("The brand palette")
struct BrandPaletteTests {
    @Test("holds the primary teal and the secondary purple the brand is drawn in")
    func keyValues() {
        #expect(BrandPalette.Teal.primary == 0x29_C0B4)
        #expect(BrandPalette.Purple.secondary == 0x61_399F)
        #expect(BrandPalette.Purple.secondaryMiddle == 0x3E_368A)
        #expect(BrandPalette.Purple.secondaryEnd == 0x2A_5B72)
    }

    @Test("a fixed tone carries the same value in both appearances")
    func fixedTone() {
        let tone = BrandTone(0x12_151C)

        #expect(tone.dark == 0x12_151C)
        #expect(tone.light == 0x12_151C)
    }

    @Test("a pair that shares a member with the ramp points at that member")
    func pairsReuseTheRamp() {
        #expect(BrandPalette.Teal.ink.dark == BrandPalette.Teal.bright)
        #expect(BrandPalette.Teal.calloutWash.light == BrandPalette.Teal.wash)
        #expect(BrandPalette.Surface.control.dark == BrandPalette.Surface.raised)
        #expect(BrandPalette.Surface.onboardingControl.dark == BrandPalette.Surface.raised)
    }
}

/// Every tone that draws text is read, so it clears WCAG AA on every surface it is drawn on.
@Suite("The text tone ramp")
struct TextToneContrastTests {
    /// The tones that reach text, strongest first; nothing dimmer than `dim` may carry words.
    static let tones: [(String, BrandTone)] = [
        ("primary", BrandPalette.Text.primary),
        ("muted", BrandPalette.Text.muted),
        ("dim", BrandPalette.Text.dim),
    ]

    /// Every surface text sits on, the rail included: the sidebar draws its version and badges there.
    static let surfaces: [(String, BrandTone)] = [
        ("ground", BrandPalette.Surface.ground),
        ("card", BrandPalette.Surface.card),
        ("control", BrandPalette.Surface.control),
        ("rail", BrandPalette.Surface.rail),
    ]

    /// The quick panel is drawn dark whatever the desktop is, so its labels are the dark ramp.
    static let panelSurfaces: [UInt32] = [
        BrandPalette.Surface.ground.dark,
        BrandPalette.Surface.card.dark,
        BrandPalette.Surface.raised,
    ]

    @Test("every text tone clears 4.5:1 on every surface, in both appearances")
    func tonesClearAA() {
        for (tone, colour) in Self.tones {
            for (surface, ground) in Self.surfaces {
                for (appearance, pair) in [
                    ("dark", (colour.dark, ground.dark)), ("light", (colour.light, ground.light)),
                ] {
                    let measured = contrastRatio(pair.0, pair.1)
                    #expect(measured >= 4.5, "\(tone) on \(appearance) \(surface) is \(measured)")
                }
            }
        }
    }

    @Test("the ramp only ever weakens, so a dimmer name is never the stronger colour")
    func rampIsOrdered() {
        let dark = Self.tones.map { relativeLuminance($0.1.dark) }
        let light = Self.tones.map { relativeLuminance($0.1.light) }

        // Strength is lightness on a dark desktop and darkness on a light one.
        #expect(dark == dark.sorted(by: >))
        #expect(light == light.sorted(by: <))
        #expect(relativeLuminance(BrandPalette.Text.ghost) < dark.last ?? 0)
    }

    @Test("the ghost glyph clears the 3:1 a mark needs, on every surface the panel draws it on")
    func ghostClearsNonText() {
        for ground in Self.panelSurfaces {
            let measured = contrastRatio(BrandPalette.Text.ghost, ground)
            #expect(measured >= 3, "ghost on \(String(ground, radix: 16)) is \(measured)")
        }
    }
}

/// Text drawn in a semantic colour is read, so it clears WCAG AA wherever it is drawn.
@Suite("The semantic text inks")
struct SemanticInkContrastTests {
    /// Every ink that draws text, by name.
    static let inks: [(String, BrandTone)] = [
        ("warning", BrandPalette.Semantic.warningInk),
        ("success", BrandPalette.Semantic.successInk),
        ("critical", BrandPalette.Semantic.criticalInk),
        ("accent", BrandPalette.Teal.ink),
    ]

    /// The share of the ink in a pill's wash, as `MainTone.background` draws it.
    static let pillWash = 0.16

    @Test("every text ink clears 4.5:1 on a card, the ground and its own pill wash, in both appearances")
    func inksClearAA() {
        let surfaces = [BrandPalette.Surface.card, BrandPalette.Surface.ground]
        for (name, ink) in Self.inks {
            for surface in surfaces {
                for (colour, ground) in [(ink.dark, surface.dark), (ink.light, surface.light)] {
                    let plain = contrastRatio(colour, ground)
                    let washed = blend(colour, over: ground, share: Self.pillWash)
                    let pill = contrastRatio(colour, washed)
                    #expect(plain >= 4.5, "\(name) on \(String(ground, radix: 16)) is \(plain)")
                    #expect(pill >= 4.5, "\(name) pill on \(String(ground, radix: 16)) is \(pill)")
                }
            }
        }
    }

    @Test("the fixed fills the inks replace fail on a light card, which is why text does not use them")
    func fillsFailAsText() {
        let card = BrandPalette.Surface.card.light
        #expect(contrastRatio(BrandPalette.Semantic.warning, card) < 4.5)
        #expect(contrastRatio(BrandPalette.Semantic.success, card) < 4.5)
        #expect(contrastRatio(BrandPalette.Semantic.recording, card) < 4.5)
    }

    @Test("the contrast arithmetic agrees with the known extremes")
    func arithmetic() {
        #expect(abs(contrastRatio(0x00_0000, 0xFF_FFFF) - 21) < 0.001)
        #expect(contrastRatio(0x12_3456, 0x12_3456) == 1)
        #expect(blend(0xFF_FFFF, over: 0x00_0000, share: 0.5) == 0x80_8080)
    }
}
