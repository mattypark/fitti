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
                    // Real captures first — a piece photographed thirty seconds
                    // ago should be the first thing you see.
                    ForEach(state.captures) { item in
                        CaptureTile(item: item, palette: state.palette)
                    }
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
        .task {
            await state.adoptSharedItems()
            await state.reloadCaptures()
            // Anything left mid-flight by a previous launch resumes here.
            await CaptureWorker.shared.drain()
            await state.reloadCaptures()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("YOUR CLOSET")
                .font(.fittiTitle)
                .foregroundStyle(state.palette.onGround)

            LimitMeter(used: state.totalPieces, limit: Entitlements.freeLimit)
                .foregroundStyle(state.palette.onGround)
        }
    }
}
