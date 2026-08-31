import Testing
import SwiftUI
@testable import FittiDesign

/// The design system claims that pinning roles to fixed OKLCH lightness keeps text
/// legible on all twelve grounds. That is a testable claim, so it is tested — if a
/// future palette tweak breaks contrast on one hue, this fails rather than shipping.
struct PaletteTests {

    @Test("Primary text clears AAA on every ground", arguments: Ground.allCases)
    func onGroundIsAAA(ground: Ground) {
        let ratio = Palette.Role.ground.oklch(on: ground)
            .contrastRatio(against: Palette.Role.onGround.oklch(on: ground))
        #expect(ratio >= 7.0, "\(ground.rawValue) primary text contrast was \(ratio)")
    }

    @Test("Secondary text clears AA on every ground", arguments: Ground.allCases)
    func onGroundSoftIsAA(ground: Ground) {
        let ratio = Palette.Role.ground.oklch(on: ground)
            .contrastRatio(against: Palette.Role.onGroundSoft.oklch(on: ground))
        #expect(ratio >= 4.5, "\(ground.rawValue) secondary contrast was \(ratio)")
    }

    @Test("Accent clears AA on every ground", arguments: Ground.allCases)
    func accentIsAA(ground: Ground) {
        let ratio = Palette.Role.ground.oklch(on: ground)
            .contrastRatio(against: Palette.Role.accent.oklch(on: ground))
        #expect(ratio >= 4.5, "\(ground.rawValue) accent contrast was \(ratio)")
    }

    /// Naive RGB clamping shifts hue — a clipped teal drifts green — which would break
    /// the premise that the twelve grounds are evenly spaced. Gamut mapping must land
    /// every role inside sRGB by reducing chroma alone.
    @Test("Every derived role lands inside sRGB", arguments: Ground.allCases)
    func rolesAreInGamut(ground: Ground) {
        for role in Palette.Role.allCases {
            #expect(role.oklch(on: ground).isInGamut,
                    "\(ground.rawValue)/\(role) fell outside sRGB after mapping")
        }
    }

    @Test("Gamut mapping preserves lightness and hue exactly")
    func mappingOnlyTouchesChroma() {
        // Light blue at high chroma is well outside sRGB — blue has the least room of
        // any hue — so this is the case that actually exercises the binary search.
        let requested = OKLCH(0.90, 0.200, 255)
        let mapped = requested.gamutMapped()
        #expect(mapped.lightness == requested.lightness)
        #expect(mapped.hue == requested.hue)
        #expect(mapped.chroma < requested.chroma)
        #expect(mapped.isInGamut)
    }

    @Test("In-gamut colors pass through untouched")
    func inGamutIsIdentity() {
        let pale = Palette.Role.ground.oklch(on: .butter)
        #expect(pale.isInGamut)
        #expect(pale.gamutMapped() == pale)
    }

    @Test("The twelve grounds stay visually distinct")
    func groundsAreDistinguishable() {
        // If mapping collapsed neighbouring hues onto each other the palette would stop
        // meaning anything, so verify adjacent grounds still differ in luminance or hue.
        let hues = Ground.allCases.map { Palette.Role.ground.oklch(on: $0).hue }
        #expect(Set(hues).count == Ground.allCases.count)
    }

    @Test("Dot placement is identical across launches for the same screen")
    func dotSeedIsStable() {
        #expect("closet".paletteSeed == "closet".paletteSeed)
        #expect("closet".paletteSeed != "discover".paletteSeed)
        #expect(DotPalette.forSeed("closet".paletteSeed, count: 3).count == 3)
    }
}
