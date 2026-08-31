import SwiftUI
import FittiDesign

struct YouView: View {
    @Bindable var state: AppState

    private let swatches = [GridItem(.adaptive(minimum: 52), spacing: Space.sm)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("YOU")
                    .font(.fittiTitle)
                    .foregroundStyle(state.palette.onGround)

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("YOUR COLOUR")
                        .fittiLabelStyle()
                        .foregroundStyle(state.palette.onGroundSoft)

                    Text(state.groundIsAuto
                         ? "Picked from the clothes you wear most."
                         : "You chose this one.")
                        .font(.fittiCallout)
                        .foregroundStyle(state.palette.onGroundSoft)

                    LazyVGrid(columns: swatches, spacing: Space.sm) {
                        ForEach(Ground.allCases, id: \.self) { ground in
                            swatch(ground)
                        }
                    }
                    .padding(.top, Space.xxs)
                }

                LimitMeter(used: state.garments.count, limit: MockCloset.limit)
                    .foregroundStyle(state.palette.onGround)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private func swatch(_ ground: Ground) -> some View {
        let isSelected = state.ground == ground
        return Button {
            withAnimation(Motion.blob) {
                state.ground = ground
                state.groundIsAuto = false
            }
        } label: {
            BlobShape(seed: ground.rawValue.paletteSeed, wobble: 0.18)
                .fill(Color(Palette.Role.ground.oklch(on: ground)))
                .overlay {
                    BlobShape(seed: ground.rawValue.paletteSeed, wobble: 0.18)
                        .stroke(Color(Palette.Role.onGround.oklch(on: ground)),
                                lineWidth: isSelected ? 2.5 : 0)
                }
                .frame(height: 52)
        }
        .buttonStyle(.squash)
        .accessibilityLabel(ground.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
