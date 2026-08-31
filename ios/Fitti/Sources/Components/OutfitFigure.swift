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
        VStack(spacing: 0) {
            // head
            Circle()
                .fill(skin)
                .frame(width: height * 0.13, height: height * 0.13)

            // top
            BlobShape(seed: outfit.id.uuidString.paletteSeed, wobble: 0.09)
                .fill(color(outfit.topHue, 0.62))
                .frame(width: height * 0.34, height: height * 0.33)
                .offset(y: -height * 0.015)

            // bottom
            RoundedRectangle(cornerRadius: height * 0.05, style: .continuous)
                .fill(color(outfit.bottomHue, 0.48))
                .frame(width: height * 0.27, height: height * 0.42)
                .offset(y: -height * 0.02)

            // shoes
            Capsule()
                .fill(color(outfit.shoeHue, 0.42))
                .frame(width: height * 0.24, height: height * 0.05)
                .offset(y: -height * 0.015)
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
        VStack(spacing: 0) {
            Circle()
                .fill(palette.onGroundSoft.opacity(0.14))
                .frame(width: height * 0.13, height: height * 0.13)
            BlobShape(seed: "ghost".paletteSeed, wobble: 0.1)
                .fill(palette.onGroundSoft.opacity(0.12))
                .frame(width: height * 0.34, height: height * 0.33)
                .offset(y: -height * 0.015)
            RoundedRectangle(cornerRadius: height * 0.05, style: .continuous)
                .fill(palette.onGroundSoft.opacity(0.10))
                .frame(width: height * 0.27, height: height * 0.42)
                .offset(y: -height * 0.02)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
