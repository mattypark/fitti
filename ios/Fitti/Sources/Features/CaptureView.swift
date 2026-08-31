import SwiftUI
import FittiDesign

/// The capture sheet.
///
/// The real camera arrives in stage 5. What matters here is that the shutter is
/// enormous, sits under the thumb, and that nothing else on screen asks for
/// anything — no name field, no category picker, no save button. Adding a piece
/// should cost exactly one tap, and the shell has to prove that before the camera
/// is worth wiring up.
struct CaptureView: View {
    let palette: Palette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shots = 0
    @State private var flash = false

    var body: some View {
        ZStack {
            Fixed.ink.ignoresSafeArea()

            VStack {
                HStack {
                    Button("Done") { dismiss() }
                        .font(.fittiHeadline)
                        .foregroundStyle(Fixed.paper)
                    Spacer()
                    if shots > 0 {
                        Text("\(shots) added")
                            .font(.fittiCallout)
                            .foregroundStyle(Fixed.yellow)
                            .monospacedDigit()
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.md)

                Spacer()

                Text(shots == 0 ? "Point at a piece" : "Keep going")
                    .font(.fittiHand)
                    .foregroundStyle(Fixed.paper.opacity(0.6))

                Spacer()

                shutter
                    .padding(.bottom, Space.xxl)
            }

            if flash {
                Fixed.paper.opacity(0.5).ignoresSafeArea().allowsHitTesting(false)
            }
        }
    }

    private var shutter: some View {
        Button {
            shots += 1
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.06)) { flash = true }
            withAnimation(.easeIn(duration: 0.18).delay(0.06)) { flash = false }
        } label: {
            ZStack {
                BlobShape(seed: "shutter".paletteSeed, wobble: 0.12)
                    .fill(Fixed.yellow)
                Image(systemName: "camera.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Fixed.ink)
            }
            .frame(width: 92, height: 92)
        }
        .buttonStyle(.squash)
        .accessibilityLabel("Take a photo")
    }
}
