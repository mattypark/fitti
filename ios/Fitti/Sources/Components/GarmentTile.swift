import SwiftUI
import FittiDesign

/// One garment in the closet grid.
///
/// No card behind it. A cutout already has a silhouette, and putting it inside a
/// rounded rectangle is a second shape competing with the first — the "nested
/// cards" tell. The negative space between cutouts is what makes a closet read as
/// a closet rather than as a dashboard.
///
/// No forced square. A coat is tall and a belt is wide; forcing both into 1:1
/// wastes most of the cell and normalises exactly the variety that makes a wall
/// of clothes look curated rather than algorithmic.
///
/// No per-tile entrance animation. This lives in a lazy stack, so `.onAppear`
/// fires on scroll-in and every tile pops as you scroll past. One container-level
/// fade, once, is the version that doesn't announce itself.
///
/// The shape itself comes from `MockGarment.tileAspectRatio`, because
/// `StaggeredGrid` has to know it before it can pack a column.
struct GarmentTile: View {
    let garment: MockGarment
    let palette: Palette

    var body: some View {
        LiquidBlob(seed: garment.name.paletteSeed,
                   base: OKLCH(0.68, 0.13, garment.hue),
                   wobble: 0.14,
                   glow: 22)
            .aspectRatio(garment.tileAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xs)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(garment.name), \(garment.category), worn \(garment.timesWorn) times")
    }
}
