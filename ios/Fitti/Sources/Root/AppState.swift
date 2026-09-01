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
    var tab: Tab = {
        #if DEBUG
        // Screenshot/UI-test affordance, DEBUG-only so it cannot ship.
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-fittiTab"),
           index + 1 < ProcessInfo.processInfo.arguments.count {
            switch ProcessInfo.processInfo.arguments[index + 1] {
            case "closet": return .closet
            case "discover": return .discover
            case "you": return .you
            default: break
            }
        }
        #endif
        return .outfits
    }()
    var isCapturing = false

    /// The personal accent. Assigned at signup today; later derived from the
    /// dominant colour of the clothes you own, and always overridable here.
    ///
    /// It no longer tints the screen — the ground is one butter for everybody —
    /// so this shows up on a ring, an active tab and a price.
    var ground: Ground = GroundStore.ground
    var groundIsAuto = GroundStore.isAutomatic

    var garments: [MockGarment] = {
        #if DEBUG
        // Lets the empty state be launched into and screenshotted. DEBUG-only,
        // like -fittiSignedIn and -fittiTab, so it cannot ship.
        if ProcessInfo.processInfo.arguments.contains("-fittiEmpty") { return [] }
        #endif
        return MockCloset.garments
    }()

    /// Shown when capture is tapped and the closet is already at the ceiling.
    var showPaywall = false

    /// Asked once, before any photo could reach an outside service.
    var showAIConsent = false

    let entitlements = Entitlements()

    /// Discover is the only screen whose content comes from outside, so it is the
    /// only one that can be empty for a reason the user can do something about.
    let reachability = Reachability()

    /// Real captures, newest first. Shown ahead of the mock pieces so a photo
    /// taken thirty seconds ago is the first thing in the grid.
    var captures: [CaptureItem] = []

    func reloadCaptures() async {
        captures = await CaptureQueue.shared.all().reversed()
    }

    /// Adopts anything the share extension saved while the app was closed. The
    /// extension only copies bytes and leaves a note; this is where those become
    /// real queue items.
    func adoptSharedItems() async {
        let filenames = SharedInbox.drain()
        guard !filenames.isEmpty else { return }
        for filename in filenames {
            await CaptureQueue.shared.adopt(filename: filename, source: .shareExtension)
        }
        await reloadCaptures()
    }

    var palette: Palette { Palette(ground) }

    /// Picking a colour has to survive a relaunch, which it did not before: the
    /// server's random assignment never reached the device and a hand-picked
    /// accent was gone by the next launch.
    func chooseGround(_ colour: Ground) {
        ground = colour
        groundIsAuto = false
        GroundStore.ground = colour
        GroundStore.isAutomatic = false
    }

    /// The client's copy of the rule. The database enforces the same ceiling in
    /// `enforce_garment_limit`, so this only decides whether to open the camera
    /// or the paywall — it is not what actually stops a 26th garment.
    var totalPieces: Int { garments.count + captures.count }

    var canAddGarment: Bool {
        entitlements.canAdd(currentCount: totalPieces)
    }

    func requestCapture() {
        guard canAddGarment else {
            showPaywall = true
            return
        }
        // Ask before the first capture rather than at launch: by now the user
        // knows what the app is for, so the question means something.
        if !AIConsent.hasDecided {
            showAIConsent = true
            return
        }
        isCapturing = true
    }
}

/// The chosen accent, across launches.
///
/// The raw string is stored, never the enum: `UserDefaults` throws on anything
/// that is not a property-list value, and that exact mistake — writing a
/// non-plist value straight in — already crashed sign-in once.
///
/// This is the local half. `profiles.ground` is assigned at signup and is still
/// not read on the session path; see docs/NEXT.md.
enum GroundStore {
    private static let colourKey = "fitti.ground"
    private static let isAutoKey = "fitti.groundIsAuto"

    static var ground: Ground {
        get {
            guard let raw = UserDefaults.standard.string(forKey: colourKey) else {
                return .default
            }
            return Ground(rawValue: raw) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: colourKey) }
    }

    /// Absent means "never chosen", which is not the same as false.
    static var isAutomatic: Bool {
        get { UserDefaults.standard.object(forKey: isAutoKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: isAutoKey) }
    }
}
