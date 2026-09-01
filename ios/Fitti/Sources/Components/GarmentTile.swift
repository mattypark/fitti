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
/// No per-tile entrance animation. This lives in a LazyVGrid, so `.onAppear`
/// fires on scroll-in and every tile pops as you scroll past. One container-level
/// fade, once, is the version that doesn't announce itself.
struct GarmentTile: View {
    let garment: MockGarment
    let palette: Palette

    /// Until real cutouts land, the placeholder carries the garment's own colour
    /// and a category-appropriate shape, so the grid's rhythm is honest about
    /// what it will look like.
    private var aspect: CGFloat {
        switch garment.category.lowercased() {
        case "outerwear", "dress": 0.72
        case "bottom": 0.78
        case "footwear": 1.25
        case "accessory": 1.35
        default: 0.92
        }
    }

    var body: some View {
        BlobShape(seed: garment.name.paletteSeed, wobble: 0.14)
            .fill(Color(OKLCH(0.68, 0.13, garment.hue)))
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xs)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(garment.name), \(garment.category), worn \(garment.timesWorn) times")
    }
}
