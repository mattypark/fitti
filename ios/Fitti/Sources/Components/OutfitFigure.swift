import SwiftUI
import FittiDesign

/// An outfit shown on a body rather than as a flat list of pieces.
///
/// Clothes only mean something worn — a stack of thumbnails tells you what you
/// own, a figure tells you what you'd look like. Real photography replaces this
/// once capture is producing cutouts; the shape and proportions are what the
/// layout is being built against.
struct OutfitFigure: View {
    let outfit: WornOutfit
    var height: CGFloat = 220
    var isGhost: Bool = false

    var body: some View {
        // Proportions matter more than detail here. Equal-width stacked shapes
        // read as a snowman; a narrow head, shoulders wider than the head, and
        // legs longer than the torso read as a person even at 74pt.
        VStack(spacing: -height * 0.012) {
            Circle()
                .fill(skin)
                .frame(width: height * 0.115, height: height * 0.115)

            // Top: widest element, short. Shoulders are what say "clothed body".
            BlobShape(seed: outfit.id.uuidString.paletteSeed, wobble: 0.06)
                .fill(color(outfit.topHue, 0.60))
                .frame(width: height * 0.30, height: height * 0.30)

            // Bottom: narrower than the top and longer, which is what makes it
            // read as legs rather than as a second torso.
            UnevenRoundedRectangle(
                topLeadingRadius: height * 0.02,
                bottomLeadingRadius: height * 0.05,
                bottomTrailingRadius: height * 0.05,
                topTrailingRadius: height * 0.02,
                style: .continuous
            )
            .fill(color(outfit.bottomHue, 0.46))
            .frame(width: height * 0.20, height: height * 0.40)

            Capsule()
                .fill(color(outfit.shoeHue, 0.38))
                .frame(width: height * 0.23, height: height * 0.045)
        }
        .frame(height: height)
        .opacity(isGhost ? 0.22 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Outfit worn by \(outfit.wearer)")
    }

    private var skin: Color {
        Color(OKLCH(isGhost ? 0.80 : 0.72, 0.04, 60))
    }

    private func color(_ hue: Double, _ lightness: Double) -> Color {
        Color(OKLCH(lightness, isGhost ? 0.02 : 0.11, hue))
    }
}

/// The empty silhouette for a day nothing was logged.
struct GhostFigure: View {
    var height: CGFloat = 220
    let palette: Palette

    var body: some View {
        VStack(spacing: -height * 0.012) {
            Circle()
                .fill(palette.onGroundSoft.opacity(0.14))
                .frame(width: height * 0.115, height: height * 0.115)
            BlobShape(seed: "ghost".paletteSeed, wobble: 0.06)
                .fill(palette.onGroundSoft.opacity(0.12))
                .frame(width: height * 0.30, height: height * 0.30)
            UnevenRoundedRectangle(
                topLeadingRadius: height * 0.02,
                bottomLeadingRadius: height * 0.05,
                bottomTrailingRadius: height * 0.05,
                topTrailingRadius: height * 0.02,
                style: .continuous
            )
            .fill(palette.onGroundSoft.opacity(0.10))
            .frame(width: height * 0.20, height: height * 0.40)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
