import SwiftUI

/// A color expressed in OKLCH — perceptually uniform lightness, chroma, and hue.
///
/// Fitti derives a whole screen's palette from one hue angle, so the roles are pinned
/// to fixed lightness and chroma and only `hue` varies. That only holds up in a
/// perceptually uniform space: in HSL, `L: 0.34` yellow and `L: 0.34` blue have wildly
/// different apparent lightness, and the text contrast would drift from AAA to
/// unreadable as the user's ground color changed.
public struct OKLCH: Equatable, Sendable {
    /// Perceptual lightness, 0...1.
    public var lightness: Double
    /// Chroma. Unbounded in theory; the sRGB ceiling depends on both lightness and hue,
    /// which is what `gamutMapped()` exists to handle.
    public var chroma: Double
    /// Hue angle in degrees.
    public var hue: Double

    public init(_ lightness: Double, _ chroma: Double, _ hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = (hue.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    /// Same color, hue rotated. Used for the accent, which sits 25° off the ground.
    public func rotated(by degrees: Double) -> OKLCH {
        OKLCH(lightness, chroma, hue + degrees)
    }
}

public extension OKLCH {
    /// Unclamped linear-light sRGB. Channels outside 0...1 mean the color does not
    /// exist in sRGB at this lightness and chroma.
    var rawSRGB: (red: Double, green: Double, blue: Double) {
        let radians = hue * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)

        // OKLab to nonlinear LMS.
        let lCone = lightness + 0.3963377774 * a + 0.2158037573 * b
        let mCone = lightness - 0.1055613458 * a - 0.0638541728 * b
        let sCone = lightness - 0.0894841775 * a - 1.2914855480 * b

        let l = lCone * lCone * lCone
        let m = mCone * mCone * mCone
        let s = sCone * sCone * sCone

        // LMS to linear sRGB, then gamma encode.
        return (
            Self.gammaEncode( 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            Self.gammaEncode(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            Self.gammaEncode(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        )
    }

    public var isInGamut: Bool {
        let (r, g, b) = rawSRGB
        let tolerance = 1e-6
        return [r, g, b].allSatisfy { $0 >= -tolerance && $0 <= 1 + tolerance }
    }

    /// The closest in-gamut color with the *same lightness and hue*, found by reducing
    /// chroma only.
    ///
    /// This is the whole reason the palette can be generated rather than hand-picked.
    /// Naively clamping RGB channels shifts hue — a clipped teal drifts visibly green —
    /// so the twelve grounds would stop being twelve evenly spaced hues. Reducing
    /// chroma instead desaturates slightly and keeps the hue exact, and because
    /// lightness is untouched, every contrast guarantee in `docs/DESIGN.md` survives
    /// the mapping.
    public func gamutMapped() -> OKLCH {
        if isInGamut { return self }

        var low = 0.0
        var high = chroma
        // 20 halvings resolves chroma to ~1e-6 — far below a perceptible step.
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if OKLCH(lightness, mid, hue).isInGamut { low = mid } else { high = mid }
        }
        return OKLCH(lightness, low, hue)
    }

    /// Display-ready sRGB: gamut-mapped, then clamped against floating-point residue.
    var srgb: (red: Double, green: Double, blue: Double) {
        let (r, g, b) = gamutMapped().rawSRGB
        return (min(max(r, 0), 1), min(max(g, 0), 1), min(max(b, 0), 1))
    }

    /// WCAG relative luminance. Lives here because contrast is a property of the color,
    /// and the design system's guarantees are stated in contrast terms.
    var relativeLuminance: Double {
        let (r, g, b) = srgb
        func linearize(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    func contrastRatio(against other: OKLCH) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func gammaEncode(_ channel: Double) -> Double {
        // Preserve the sign so out-of-gamut negatives stay detectable.
        let magnitude = abs(channel)
        let encoded = magnitude <= 0.0031308
            ? 12.92 * magnitude
            : 1.055 * pow(magnitude, 1 / 2.4) - 0.055
        return channel < 0 ? -encoded : encoded
    }
}

public extension Color {
    init(_ oklch: OKLCH) {
        let (r, g, b) = oklch.srgb
        // .sRGB, not .sRGBLinear — srgb is already gamma-encoded.
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
