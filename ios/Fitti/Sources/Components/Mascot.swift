import SwiftUI
import FittiDesign

/// Fitti himself. Breathes on his own, and squashes when poked.
///
/// Squash-and-stretch is the house move — press anything in this app and it
/// compresses on the press axis while widening on the other. The mascot is where
/// that language is most literal.
struct Mascot: View {
    var size: CGFloat = 96
    /// Set true while something is happening, and he bounces faster.
    var isBusy: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var poked = false

    var body: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .onTapGesture { poke() }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: isBusy ? 0.5 : 2.2)
                    .repeatForever(autoreverses: true)
                ) { breathing = true }
            }
            .accessibilityLabel("Fitti")
            .accessibilityAddTraits(.isImage)
    }

    private var scaleX: CGFloat {
        if poked { return 1.12 }
        return breathing ? 1.02 : 1.0
    }

    private var scaleY: CGFloat {
        if poked { return 0.88 }
        return breathing ? 0.98 : 1.0
    }

    private func poke() {
        guard !reduceMotion else { return }
        withAnimation(Motion.blob) { poked = true }
        // Let the spring carry him back rather than animating a return — the
        // overshoot is the whole character.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(Motion.blob) { poked = false }
        }
    }
}
