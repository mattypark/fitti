import SwiftUI
import FittiDesign

struct ClosetView: View {
    @Bindable var state: AppState

    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                if items.isEmpty {
                    StateView(kind: .empty,
                              message: "nothing in here yet — tap the +\nand I'll start remembering what you own",
                              foreground: state.palette.onGround,
                              actionTitle: "Add a piece") { state.requestCapture() }
                } else {
                // Two columns, not three. Three at iPhone width turns a wall of
                // clothes into a spreadsheet; two is what Alta and Cosmos both
                // settle on, and it leaves each silhouette large enough to be
                // recognised rather than merely counted.
                StaggeredGrid(items: items,
                              columns: 2,
                              spacing: Space.sm,
                              aspectRatio: \.aspectRatio) { item in
                    switch item {
                    case .capture(let capture):
                        CaptureTile(item: capture, palette: state.palette)
                    case .garment(let garment):
                        GarmentTile(garment: garment, palette: state.palette)
                    }
                }
                // One fade for the whole grid, not one per tile.
                .opacity(loaded ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: loaded)
                }
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

    /// Real captures first — a piece photographed thirty seconds ago should be
    /// the first thing you see.
    private var items: [ClosetItem] {
        state.captures.map(ClosetItem.capture) + state.garments.map(ClosetItem.garment)
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

/// Captures and garments share one grid, so they need one identity and one
/// declared shape. The grid packs columns before anything is drawn, which is why
/// the aspect ratio has to be answerable up front rather than measured.
private enum ClosetItem: Identifiable {
    case capture(CaptureItem)
    case garment(MockGarment)

    var id: String {
        switch self {
        case .capture(let item): "capture-\(item.id)"
        case .garment(let garment): "garment-\(garment.id)"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        // A capture is square until its cutout lands and the real silhouette
        // replaces the thumbnail.
        case .capture: 1
        case .garment(let garment): garment.tileAspectRatio
        }
    }
}
