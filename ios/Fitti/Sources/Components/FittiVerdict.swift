import SwiftUI
import FittiDesign
import FittiEngine

/// Fitti looking at an outfit and having an opinion about it.
///
/// The outfit sits behind and above him, and he glances toward it — the glance is
/// what makes it read as *his* opinion rather than a rating printed next to a
/// picture. Expression comes from the same engine score the suggestion list uses,
/// so he cannot disagree with the app's own ranking.
struct FittiVerdict: View {
    let outfit: Outfit
    let palette: Palette
    var size: CGFloat = 128

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var mood: Mood { Mood(score: outfit.score) }

    var body: some View {
        VStack(spacing: Space.sm) {
            ZStack(alignment: .bottomLeading) {
                // The outfit, floating behind his shoulder.
                outfitStack
                    .offset(x: size * 0.74, y: -size * 0.46)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.7,
                                 anchor: .bottomLeading)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                FittiCharacter(
                    size: size,
                    mood: mood,
                    // He looks toward the outfit, which is up and to his right.
                    gaze: appeared ? 0.85 : 0
                )
            }
            .frame(height: size * 1.35)

            Text(verdict)
                .font(.fittiHand)
                .foregroundStyle(palette.onGroundSoft)
                .multilineTextAlignment(.center)
                .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .onAppear {
            // The outfit arrives first, then he reacts to it. Reversing that
            // makes him look like he is reacting to nothing.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fitti's take: \(verdict)")
    }

    /// The pieces, stacked as they'd be worn.
    private var outfitStack: some View {
        VStack(spacing: -size * 0.03) {
            ForEach(Array(outfit.pieces.enumerated()), id: \.element.id) { index, piece in
                BlobShape(seed: piece.id.paletteSeed, wobble: 0.13)
                    .fill(Color(OKLCH(0.66, max(piece.chroma, 0.06), piece.hue)))
                    .frame(width: size * 0.34, height: size * 0.29)
                    .rotationEffect(.degrees(Double(index) * 5 - 5))
            }
        }
        .padding(size * 0.05)
        .background(palette.groundLift.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    /// His words. Uses the engine's own reason when it has one, because a made-up
    /// compliment is worse than a specific observation.
    private var verdict: String {
        if let reason = outfit.reasons.first { return reason }
        switch mood {
        case .delighted: return "oh this is good"
        case .pleased: return "yeah, this works"
        case .neutral: return "it'll do"
        case .unsure: return "hmm, not sure"
        case .asleep: return "..."
        }
    }
}
