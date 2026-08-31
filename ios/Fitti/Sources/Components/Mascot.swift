import SwiftUI
import FittiDesign

/// Fitti himself.
///
/// A thin wrapper over `FittiBlob` so every existing call site gets the shader
/// treatment without changing. The `isBusy` flag raises the wobble rather than
/// swapping to a different animation — one behaviour, dialled up.
struct Mascot: View {
    var size: CGFloat = 96
    /// Livelier while something is happening.
    var isBusy: Bool = false

    var body: some View {
        FittiBlob(size: size, amplitude: isBusy ? 24 : 12)
    }
}
