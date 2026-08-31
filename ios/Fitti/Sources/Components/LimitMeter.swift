import SwiftUI
import FittiDesign

/// The free-plan ceiling, drawn as a blob that fills up.
///
/// It gets visibly tighter as it fills — the wobble drops off, so a nearly-full
/// meter reads as tense before you have read the number. That is the point: the
/// paywall should be felt, not announced.
struct LimitMeter: View {
    let used: Int
    let limit: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    private var fraction: Double {
        min(Double(used) / Double(max(limit, 1)), 1)
    }

    /// Slack at 0, taut at the ceiling.
    private var wobble: Double { 0.22 * (1 - fraction * 0.8) }

    var body: some View {
        HStack(spacing: Space.sm) {
            ZStack {
                BlobShape(seed: "limit".paletteSeed, wobble: wobble, phase: phase)
                    .fill(Color.primary.opacity(0.08))

                BlobShape(seed: "limit".paletteSeed, wobble: wobble, phase: phase)
                    .fill(Fixed.yellow)
                    .mask(alignment: .bottom) {
                        // Fills from the bottom, like liquid rather than a bar.
                        GeometryReader { geometry in
                            Rectangle()
                                .frame(height: geometry.size.height * fraction)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(used) of \(limit)")
                    .font(.fittiHeadline)
                    .monospacedDigit()
                Text(used >= limit ? "Closet full" : "pieces saved")
                    .font(.fittiCallout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(used) of \(limit) pieces saved")
    }
}
