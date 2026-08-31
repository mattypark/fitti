import SwiftUI
import FittiDesign

struct ClosetView: View {
    @Bindable var state: AppState

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: Space.grid)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                LazyVGrid(columns: columns, spacing: Space.grid) {
                    ForEach(state.garments) { garment in
                        GarmentTile(garment: garment, palette: state.palette)
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("YOUR CLOSET")
                .font(.fittiTitle)
                .foregroundStyle(state.palette.onGround)

            LimitMeter(used: state.garments.count, limit: MockCloset.limit)
                .foregroundStyle(state.palette.onGround)
        }
    }
}
