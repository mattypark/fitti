import SwiftUI

/// The twelve personal colors. A user is assigned one at signup; later it becomes the
/// dominant color of the clothes they own, and it is always overridable in Appearance.
///
/// The name is historical. This used to tint the whole screen; it now drives the
/// `accent` role alone — see `Palette.Role`. It stays `Ground` because the value is
/// persisted as `profiles.ground` and the raw strings are the column's check constraint.
public enum Ground: String, CaseIterable, Codable, Sendable {
    case butter, amber, terracotta, rose, blush, orchid
    case violet, blue, sky, teal, jade, moss

    /// Yellow is the brand, so it is also the default.
    public static let `default` = Ground.butter

    /// The hue angle this user's accent is derived from.
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

/// Every color on a Fitti screen.
///
/// The roles are fixed points in OKLCH — see `docs/DESIGN.md`. Pinning lightness rather
/// than picking swatches is what keeps `onGround` at ~14:1 against `ground` and every
/// one of the twelve accents above 4.5:1 on the same field.
public struct Palette: Equatable, Sendable {

    /// Butter. Every surface and text role is pinned to this angle, so the app is one
    /// colour for everybody and only the accent is personal.
    static let brandHue: Double = Ground.butter.hue

    /// The six semantic slots. Each is a fixed lightness/chroma pair; five of them sit
    /// on the brand hue and only `accent` rotates with the user.
    public enum Role: CaseIterable, Sendable {
        /// The whole screen.
        case ground
        /// Recessed: the tab bar, wells, pressed states.
        case groundSunk
        /// Raised: sheets and cards that must sit above the ground.
        case groundLift
        /// All primary text.
        case onGround
        /// Secondary text, metadata, counts.
        case onGroundSoft
        /// Price, destructive, the one thing that must be seen. The only personal role.
        case accent

        /// Pigment, and one pigment.
        ///
        /// A previous pass took the ground to L 0.985 / C 0.004 — paper. It solved a
        /// real problem (simultaneous contrast biases hue judgement, and butter sits
        /// opposite the H 220-255 band where every navy and denim clusters) but it
        /// solved it by deleting the brand from the screen: all twelve grounds landed
        /// within about five RGB points of #FAFAFA, and the launch screen still opened
        /// on butter and then flashed to white.
        ///
        /// The fix is scarcity, not neutrality. One warm ground everywhere, and the
        /// personal hue demoted to an accent that appears on a ring, an active tab and
        /// a price. The two screens where garment colour actually has to be judged
        /// opt out by hand: Discover runs on `Fixed.paper`, Capture on `Fixed.ink`.
        var lightness: Double {
            switch self {
            case .ground: 0.900
            case .groundSunk: 0.855
            case .groundLift: 0.945
            case .onGround: 0.180
            case .onGroundSoft: 0.460
            case .accent: 0.460
            }
        }

        /// Surfaces carry enough chroma to read as butter rather than as beige; text
        /// carries almost none so it stays ink rather than becoming a second colour.
        ///
        /// `accent` at 0.170 is the only saturated thing on a Fitti screen. That is
        /// what makes it read as emphasis — a brand colour used everywhere stops
        /// being a brand colour.
        var chroma: Double {
            switch self {
            case .ground: 0.075
            case .groundSunk: 0.075
            case .groundLift: 0.055
            case .onGround: 0.012
            case .onGroundSoft: 0.010
            case .accent: 0.170
            }
        }

        /// The accent sits 40° *below* its hue. In the sneaker reference the price is
        /// crimson against yellow — near enough to feel deliberate, far enough to jump.
        ///
        /// It used to be +25, which put butter's accent at 110° and gamut-mapped to a
        /// muddy olive that lost to the ground it was supposed to jump off. -40 puts
        /// butter at burnt orange and lifts the worst-case contrast across all twelve
        /// from 3.92:1 to 4.99:1.
        var hueOffset: Double {
            switch self {
            case .accent: -40
            default: 0
            }
        }

        /// The role's color for a given user. Gamut-mapped so the hue stays exact.
        public func oklch(on ground: Ground) -> OKLCH {
            let hue = switch self {
            case .accent: ground.hue + hueOffset
            default: Palette.brandHue
            }
            return OKLCH(lightness, chroma, hue).gamutMapped()
        }
    }

    public let ground: Color
    public let groundSunk: Color
    public let groundLift: Color
    public let onGround: Color
    public let onGroundSoft: Color
    public let accent: Color

    /// Tertiary text. The same ink at lower opacity, never a different colour —
    /// opacity composites correctly over the ground, over a lifted sheet and over a
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

/// The three colors that never move, whatever accent the user is on.
public enum Fixed {
    /// The mascot's marks, the app icon, statements that must be absolute.
    public static let ink = Color(red: 0.055, green: 0.055, blue: 0.047)
    /// The Discover grid — a white gallery, so the clothes are the only color on screen.
    public static let paper = Color(red: 0.984, green: 0.980, blue: 0.965)
    /// The brand mark: logo, launch screen, App Store icon.
    public static let yellow = Color(red: 0.937, green: 0.773, blue: 0.247)

    /// The same yellow in OKLCH. `JellyBlob` builds its subsurface ramp by moving
    /// lightness, which only stays the same colour if the hue is held explicitly —
    /// darkening an sRGB triple drags it toward orange.
    public static let yellowPigment = OKLCH(0.838, 0.152, 91)
}

/// Small, fast, and — unlike `SystemRandomNumberGenerator` — reproducible, which is the
/// entire point: a given garment's blob must have the same silhouette on every launch.
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
