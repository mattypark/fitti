import SwiftUI

/// The twelve screen grounds. A user is assigned one at signup; later it becomes the
/// dominant color of the clothes they own, and it is always overridable in Appearance.
public enum Ground: String, CaseIterable, Codable, Sendable {
    case butter, amber, terracotta, rose, blush, orchid
    case violet, blue, sky, teal, jade, moss

    /// Yellow is the brand, so it is also the default ground.
    public static let `default` = Ground.butter

    /// The single hue angle every color on the screen is derived from.
    public var hue: Double {
        switch self {
        case .butter:     85
        case .amber:      55
        case .terracotta: 30
        case .rose:       15
        case .blush:     350
        case .orchid:    320
        case .violet:    285
        case .blue:      255
        case .sky:       220
        case .teal:      195
        case .jade:      160
        case .moss:      130
        }
    }

    public var displayName: String { rawValue.capitalized }
}

/// Every color on a Fitti screen, derived from one hue.
///
/// The roles are fixed points in OKLCH — see `docs/DESIGN.md`. Pinning lightness rather
/// than picking swatches is what keeps `onGround` at ~7:1 against `ground` no matter
/// which of the twelve grounds the user is on.
public struct Palette: Equatable, Sendable {

    /// The six semantic slots. Each is a fixed lightness/chroma pair plus a hue offset,
    /// so the entire palette is a function of one angle.
    public enum Role: CaseIterable, Sendable {
        /// The whole screen.
        case ground
        /// Recessed: the tab bar, wells, pressed states.
        case groundSunk
        /// Raised: sheets and cards that must sit above the ground.
        case groundLift
        /// All primary text. Brown on butter, ink-teal on jade.
        case onGround
        /// Secondary text, metadata, counts.
        case onGroundSoft
        /// Price, destructive, the one thing that must be seen.
        case accent

        /// Paper, not pigment.
        ///
        /// The old system put a saturated field on every screen. That is wrong
        /// here for a reason specific to this product, not for taste: simultaneous
        /// contrast shifts the perceived hue of everything sitting on a coloured
        /// field, and butter (H 85) sits near the opposite of where garments
        /// actually cluster (H 220-255 — every navy, blue and denim). A wardrobe
        /// app whose background biases blue judgement has a bug in the one job it
        /// cannot get wrong.
        ///
        /// It also broke the cutouts. Background removal leaves a pale matting
        /// halo on the alpha edge; invisible on paper, obvious on colour.
        ///
        /// The hue survives — at C 0.004 it is a temperature rather than a colour.
        /// A butter user's paper is imperceptibly warm, a teal user's
        /// imperceptibly cool.
        var lightness: Double {
            switch self {
            case .ground: 0.985
            case .groundSunk: 0.960
            case .groundLift: 1.000   // lift is WHITER than ground, not tinted
            case .onGround: 0.180
            case .onGroundSoft: 0.480
            case .accent: 0.520
            }
        }

        /// Chroma now has one job: make `accent` visible.
        ///
        /// Every surface and text role is effectively neutral, which is exactly
        /// why the accent can be 0.170 where it previously needed 0.085 and still
        /// failed to read — it no longer competes with a coloured field for
        /// attention. Scarcity is what makes a brand colour read as branding.
        ///
        /// The hue survives at these values as a temperature rather than a
        /// colour: a butter user's paper is imperceptibly warm, a teal user's
        /// imperceptibly cool.
        var chroma: Double {
            switch self {
            case .ground: 0.004
            case .groundSunk: 0.006
            case .groundLift: 0.000
            case .onGround: 0.012
            case .onGroundSoft: 0.010
            case .accent: 0.170
            }
        }

        /// The accent sits 25° off the ground hue on purpose. In the sneaker reference
        /// the price is crimson against yellow — near enough to feel deliberate, far
        /// enough to jump. A 180° complement would read as a second brand color rather
        /// than an emphasis.
        var hueOffset: Double {
            switch self {
            case .accent: 25
            default: 0
            }
        }

        /// The role's color for a given ground, gamut-mapped so the hue stays exact.
        public func oklch(on ground: Ground) -> OKLCH {
            OKLCH(lightness, chroma, ground.hue + hueOffset).gamutMapped()
        }
    }

    public let ground: Color
    public let groundSunk: Color
    public let groundLift: Color
    public let onGround: Color
    public let onGroundSoft: Color
    public let accent: Color

    /// Tertiary text. The same ink at lower opacity, never a different colour —
    /// opacity composites correctly over paper, over a white sheet and over a
    /// garment photograph, where a fixed grey goes muddy on one and vanishes on
    /// another.
    public var onGroundFaint: Color { onGround.opacity(0.38) }

    public init(_ groundColor: Ground) {
        ground       = Color(Role.ground.oklch(on: groundColor))
        groundSunk   = Color(Role.groundSunk.oklch(on: groundColor))
        groundLift   = Color(Role.groundLift.oklch(on: groundColor))
        onGround     = Color(Role.onGround.oklch(on: groundColor))
        onGroundSoft = Color(Role.onGroundSoft.oklch(on: groundColor))
        accent       = Color(Role.accent.oklch(on: groundColor))
    }
}

/// The three colors that never move, whatever ground the user is on.
public enum Fixed {
    /// The mascot's marks, the app icon, statements that must be absolute.
    public static let ink = Color(red: 0.055, green: 0.055, blue: 0.047)
    /// The Discover grid — a white gallery, so the clothes are the only color on screen.
    public static let paper = Color(red: 0.984, green: 0.980, blue: 0.965)
    /// The brand mark: logo, launch screen, App Store icon.
    public static let yellow = Color(red: 0.937, green: 0.773, blue: 0.247)
}

/// The rainbow blob dots. Saturated enough to register on any ground, never loud enough
/// to compete with a garment.
public enum DotPalette {
    public static let all: [Color] = Ground.allCases.map { Color(OKLCH(0.72, 0.17, $0.hue)) }

    /// Deterministic per screen: the same route always gets the same dots in the same
    /// places, so they read as part of the screen rather than as noise.
    public static func forSeed(_ seed: UInt64, count: Int) -> [Color] {
        var generator = SplitMix64(seed: seed)
        return (0..<count).map { _ in all[Int(generator.next() % UInt64(all.count))] }
    }
}

/// Small, fast, and — unlike `SystemRandomNumberGenerator` — reproducible, which is the
/// entire point: the dots must land in the same spots on every launch.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public extension String {
    /// Stable across launches and across processes, which `hashValue` is not.
    var paletteSeed: UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }
}
