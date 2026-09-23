// The WCAG 2.x contrast arithmetic the palette suites measure against.

import Foundation

/// The WCAG 2.x relative luminance of an sRGB hex.
func relativeLuminance(_ hex: UInt32) -> Double {
    func linear(_ channel: UInt32) -> Double {
        let value = Double(channel) / 255
        return value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(hex >> 16 & 0xFF) + 0.7152 * linear(hex >> 8 & 0xFF)
        + 0.0722 * linear(hex & 0xFF)
}

/// The WCAG 2.x contrast ratio between two sRGB hexes.
func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
    let (a, b) = (relativeLuminance(first), relativeLuminance(second))
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
}

/// `ink` laid over `ground` at `share` opacity, channel by channel.
func blend(_ ink: UInt32, over ground: UInt32, share: Double) -> UInt32 {
    [16, 8, 0].reduce(0) { total, shift in
        let top = Double(ink >> UInt32(shift) & 0xFF)
        let bottom = Double(ground >> UInt32(shift) & 0xFF)
        return total | UInt32((top * share + bottom * (1 - share)).rounded()) << UInt32(shift)
    }
}
