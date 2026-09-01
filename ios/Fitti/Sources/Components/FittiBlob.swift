import SwiftUI
import FittiDesign

/// The mascot, alive.
///
/// One `Image` plus two Metal shaders. No sprite sheet, no video, no animation
/// runtime — the deformation is evaluated per frame on the GPU, so it runs at
/// whatever the display is doing and can take the touch position as an argument.
///
/// Requires `CADisableMinimumFrameDurationOnPhone` in Info.plist. Without it
/// iPhone caps third-party animation at 60fps even on ProMotion hardware, and
/// every spring in the design system renders as a cheaper version of itself.
struct FittiBlob: View {
    var size: CGFloat = 220
    /// 0...1. Drives the liquid fill — used by the closet limit meter.
    var level: Double = 0
    var liquid: Color = Fixed.yellow
    /// Wobble strength in points. Raise for a livelier blob.
    var amplitude: Double = 14

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var squash: Double = 0
    @State private var touch: CGPoint?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0,
                                paused: scenePhase != .active || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Image("Mascot")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .visualEffect { content, proxy in
                    let bounds = proxy.size
                    let point = touch ?? CGPoint(x: bounds.width / 2, y: bounds.height / 2)

                    return content
                        // Fill first, deform second: the liquid surface should
                        // stay level in view space, not tilt with the squash.
                        .colorEffect(
                            ShaderLibrary.liquidFill(
                                .float2(bounds),
                                .float(level),
                                .float(time),
                                .color(liquid)
                            ),
                            isEnabled: level > 0
                        )
                        .distortionEffect(
                            ShaderLibrary.jelly(
                                .float2(bounds),
                                .float(time),
                                .float(squash),
                                .float2(point),
                                .float(amplitude)
                            ),
                            // Must exceed the largest displacement or the edges
                            // clip. The PNG carries 15% transparent margin to
                            // give the deformation somewhere to go.
                            maxSampleOffset: CGSize(width: 56, height: 56),
                            isEnabled: !reduceMotion
                        )
                }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if squash == 0 { Haptics.shared.squish() }
                    touch = value.location
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                        squash = 1
                    }
                }
                .onEnded { _ in
                    // Loose damping on release so it overshoots and settles.
                    // That overshoot is the character.
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.32)) {
                        squash = 0
                    }
                }
        )
        .animation(.smooth(duration: 0.6), value: level)
        .accessibilityLabel("Fitti")
        .accessibilityAddTraits(.isImage)
    }
}
