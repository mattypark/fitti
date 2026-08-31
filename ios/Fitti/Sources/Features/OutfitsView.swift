import SwiftUI
import FittiDesign

struct OutfitsView: View {
    let palette: Palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("OUTFITS")
                    .font(.fittiTitle)
                    .foregroundStyle(palette.onGround)

                // The empty state carries the mascot and the handwriting, because
                // it is the screen a brand-new user sees most.
                VStack(spacing: Space.md) {
                    Mascot(size: 108)

                    Text("Add ten pieces and\nI'll start making fits")
                        .font(.fittiHand)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.onGroundSoft)

                    Text("16 of 10")
                        .font(.fittiNumeral)
                        .foregroundStyle(palette.onGround)
                        .monospacedDigit()

                    Text("READY WHEN YOU ARE")
                        .fittiLabelStyle()
                        .foregroundStyle(palette.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xxl)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)
        }
        .scrollIndicators(.hidden)
    }
}
