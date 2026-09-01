import Foundation
import Network
import Observation

/// Whether the phone can currently reach anything.
///
/// Discover is the screen that needs this: it is the only one whose content comes
/// from outside, so it is the only one that can be genuinely empty for a reason
/// the user can fix. Everything else in Fitti works on a plane.
@Observable
@MainActor
final class Reachability {
    private(set) var isOnline = true

    /// Deliberately never cancelled. There is one of these for the lifetime of the
    /// app, and a nonisolated `deinit` cannot touch the monitor under strict
    /// concurrency — so the tidy-looking version would not compile and the
    /// untidy-looking one has nothing to tidy.
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Read the status on the monitor's own queue; NWPath itself does not
            // cross to the main actor.
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "fitti.reachability", qos: .utility))
    }
}
