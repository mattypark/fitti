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

    private var fraction: Double {
        min(Double(used) / Double(max(limit, 1)), 1)
    }

    var body: some View {
        HStack(spacing: Space.sm) {
            // The mascot IS the meter: he fills with liquid as the closet does.
            // The fill is a Metal shader masked by his own alpha, so the level is
            // exact to the pixel and the baked shading survives being coloured in.
            FittiBlob(size: 38, level: fraction, liquid: Fixed.yellow, amplitude: 6)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(used) of \(limit) pieces saved")
    }
}
