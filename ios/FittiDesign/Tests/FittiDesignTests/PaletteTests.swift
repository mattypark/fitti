import Testing
import SwiftUI
@testable import FittiDesign

/// The design system claims one warm ground carries the whole app and that all twelve
/// personal accents stay legible on it. That is a testable claim, so it is tested — if a
/// future palette tweak breaks contrast on one hue, this fails rather than shipping.
struct PaletteTests {

    // MARK: - The one ground

    /// Not parameterised any more: the surface and text roles are pinned to the brand
    /// hue, so there is exactly one answer.
    @Test("Primary text clears AAA on the ground")
    func onGroundIsAAA() {
        let ratio = Palette.Role.ground.oklch(on: .butter)
            .contrastRatio(against: Palette.Role.onGround.oklch(on: .butter))
        // The floor is 12, not the AAA 7. The delivered ratio is ~13.9, and a 7.0 floor
        // is slack enough that it would not have caught the ground being inverted to
        // near-white — which is exactly the regression this file now exists to catch.
        #expect(ratio >= 12.0, "primary text contrast was \(ratio)")
    }

    /// Secondary text has to survive on all three surfaces, not just the ground. Sunk is
    /// the tight one at ~4.6:1, which is why it is asserted rather than assumed.
    @Test("Secondary text clears AA on every surface")
    func onGroundSoftIsAA() {
        let soft = Palette.Role.onGroundSoft.oklch(on: .butter)
        for surface in [Palette.Role.ground, .groundSunk, .groundLift] {
            let ratio = surface.oklch(on: .butter).contrastRatio(against: soft)
            #expect(ratio >= 4.5, "secondary on \(surface) was \(ratio)")
        }
    }

    /// The ground is one pigment for everybody, and it is actually pigment.
    @Test("The ground is warm, and identical for every user")
    func groundIsOnePigment() {
        // A ground at C 0.004 is white with an opinion. Anything below this floor means
        // the brand has left the screen again.
        #expect(Palette.Role.ground.chroma >= 0.05)

        let butter = Palette.Role.ground.oklch(on: .butter)
        for ground in Ground.allCases {
            #expect(Palette.Role.ground.oklch(on: ground) == butter,
                    "\(ground.rawValue) drew a different ground")
        }
    }

    // MARK: - The twelve accents

    @Test("Accent clears AA on the ground", arguments: Ground.allCases)
    func accentIsAA(ground: Ground) {
        let ratio = Palette.Role.ground.oklch(on: ground)
            .contrastRatio(against: Palette.Role.accent.oklch(on: ground))
        #expect(ratio >= 4.5, "\(ground.rawValue) accent contrast was \(ratio)")
    }

    /// A price sits on a lifted sheet as often as on the ground.
    @Test("Accent clears AA on lifted surfaces too", arguments: Ground.allCases)
    func accentIsAAOnLift(ground: Ground) {
        let ratio = Palette.Role.groundLift.oklch(on: ground)
            .contrastRatio(against: Palette.Role.accent.oklch(on: ground))
        #expect(ratio >= 4.5, "\(ground.rawValue) accent on lift was \(ratio)")
    }

    /// The old version of this test compared *hue angles*, which is why twelve grounds
    /// that all rendered within five RGB points of #FAFAFA passed it. Compare what the
    /// screen actually shows.
    @Test("The twelve accents stay visually distinct")
    func accentsAreDistinguishable() {
        let rendered = Ground.allCases.map { Palette.Role.accent.oklch(on: $0).srgb }

        for i in rendered.indices {
            for j in rendered.indices where j > i {
                let a = rendered[i], b = rendered[j]
                let distance = ((a.red - b.red) * (a.red - b.red)
                              + (a.green - b.green) * (a.green - b.green)
                              + (a.blue - b.blue) * (a.blue - b.blue)).squareRoot()
                let pair = "\(Ground.allCases[i].rawValue)/\(Ground.allCases[j].rawValue)"
                #expect(distance >= 0.06, "\(pair) render \(distance) apart")
            }
        }
    }

    // MARK: - Gamut mapping

    /// Naive RGB clamping shifts hue — a clipped teal drifts green — which would break
    /// the premise that the twelve accents are evenly spaced. Gamut mapping must land
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
        let surface = Palette.Role.ground.oklch(on: .butter)
        #expect(surface.isInGamut)
        #expect(surface.gamutMapped() == surface)
    }

    // MARK: - Seeding

    @Test("Blob silhouettes are identical across launches")
    func seedIsStable() {
        #expect("closet".paletteSeed == "closet".paletteSeed)
        #expect("closet".paletteSeed != "discover".paletteSeed)

        var generator = SplitMix64(seed: "closet".paletteSeed)
        var twin = SplitMix64(seed: "closet".paletteSeed)
        #expect(generator.next() == twin.next())
    }
}
