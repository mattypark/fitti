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

        var lightness: Double {
            switch self {
            case .ground: 0.89
            case .groundSunk: 0.83
            case .groundLift: 0.955
            case .onGround: 0.32
            case .onGroundSoft: 0.47
            case .accent: 0.46
            }
        }

        /// Chroma is deliberately uniform across the surface and text roles rather than
        /// "as saturated as this hue allows".
        ///
        /// sRGB holds far more chroma at yellow than at blue for the same lightness — at
        /// L 0.89 the ceiling is 0.21 for moss and 0.054 for blue. Taking a fixed
        /// *fraction* of each hue's ceiling would make a moss user's app look neon next
        /// to a blue user's washed-out one. Blue therefore sets the budget for everyone,
        /// which is why `ground` is 0.052: the most any hue can hold at L 0.89 while
        /// every hue holds the same amount.
        ///
        /// `accent` is the exception. It is a small emphasis color, not a surface, so it
        /// asks for more than blue can give and lets `gamutMapped()` pull it back per
        /// hue — hue and lightness survive, only saturation gives.
        var chroma: Double {
            switch self {
            case .ground: 0.052
            case .groundSunk: 0.052
            case .groundLift: 0.020
            case .onGround: 0.052
            case .onGroundSoft: 0.050
            case .accent: 0.085
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
    static let ink = Color(red: 0.055, green: 0.055, blue: 0.047)
    /// The Discover grid — a white gallery, so the clothes are the only color on screen.
    static let paper = Color(red: 0.984, green: 0.980, blue: 0.965)
    /// The brand mark: logo, launch screen, App Store icon.
    static let yellow = Color(red: 0.937, green: 0.773, blue: 0.247)
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
