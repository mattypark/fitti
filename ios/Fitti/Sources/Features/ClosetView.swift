import SwiftUI
import FittiDesign

struct ClosetView: View {
    @Bindable var state: AppState

    /// Column gutter tighter than the row gutter, deliberately. Equal gutters
    /// produce a mesh; unequal ones make each row read as a shelf. A single
    /// spacing value used everywhere is the "monotonous spacing" tell.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                LazyVGrid(columns: columns, spacing: Space.lg) {
                    // Real captures first — a piece photographed thirty seconds
                    // ago should be the first thing you see.
                    ForEach(state.captures) { item in
                        CaptureTile(item: item, palette: state.palette)
                    }
                    ForEach(state.garments) { garment in
                        GarmentTile(garment: garment, palette: state.palette)
                    }
                }
                // One fade for the whole grid, not one per tile.
                .opacity(loaded ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: loaded)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .onAppear { loaded = true }
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
                .fittiTitleStyle()
                .foregroundStyle(state.palette.onGround)

            LimitMeter(used: state.totalPieces, limit: Entitlements.freeLimit)
                .foregroundStyle(state.palette.onGround)
        }
    }
}
