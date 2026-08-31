import SwiftUI
import FittiDesign

/// One garment in the closet grid.
///
/// Until real cutouts land in stage 5, the "photo" is a blob in the garment's
/// dominant colour. That is enough to judge the thing that actually matters at
/// this stage: how the grid feels under a thumb.
struct GarmentTile: View {
    let garment: MockGarment
    let palette: Palette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(palette.groundLift)

            BlobShape(seed: garment.name.paletteSeed, wobble: 0.16)
                .fill(Color(OKLCH(0.68, 0.13, garment.hue)))
                .padding(18)
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.86)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(Motion.respecting(Motion.blob, reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(garment.name), \(garment.category), worn \(garment.timesWorn) times")
    }
}
