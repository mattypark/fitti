import SwiftUI
import Observation
import FittiDesign

enum Tab: Hashable, CaseIterable {
    case closet, discover, outfits, you
}

/// Shell state. Everything here is replaced by real storage in stage 5; it exists
/// now so the navigation and the ground-colour switch behave for real.
@Observable
@MainActor
final class AppState {
    var tab: Tab = .closet
    var isCapturing = false

    /// The screen colour. Assigned at signup today; later derived from the
    /// dominant colour of the clothes you own, and always overridable here.
    var ground: Ground = .butter
    var groundIsAuto = true

    var garments: [MockGarment] = MockCloset.garments

    /// Shown when capture is tapped and the closet is already at the ceiling.
    var showPaywall = false

    let entitlements = Entitlements()

    var palette: Palette { Palette(ground) }

    /// The client's copy of the rule. The database enforces the same ceiling in
    /// `enforce_garment_limit`, so this only decides whether to open the camera
    /// or the paywall — it is not what actually stops a 26th garment.
    var canAddGarment: Bool {
        entitlements.canAdd(currentCount: garments.count)
    }

    func requestCapture() {
        if canAddGarment {
            isCapturing = true
        } else {
            showPaywall = true
        }
    }

    /// Discover is deliberately paper rather than the user's ground: a white
    /// gallery, so the only colour on screen belongs to the clothes.
    var isGalleryTab: Bool { tab == .discover }
}
