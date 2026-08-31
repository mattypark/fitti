import SwiftUI
import FittiDesign

struct RootView: View {
    let session: Session
    var onSignOut: () -> Void

    @State private var state = AppState()

    var body: some View {
        ZStack(alignment: .bottom) {
            // The screen IS the colour, edge to edge. Discover is the one
            // exception, where the clothes should be the only colour present.
            (state.isGalleryTab ? Fixed.paper : state.palette.ground)
                .ignoresSafeArea()

            if !state.isGalleryTab {
                BlobDots(screen: screenName, count: 3)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Group {
                    switch state.tab {
                    case .closet:   ClosetView(state: state)
                    case .discover: DiscoverView()
                    case .outfits:  OutfitsView(palette: state.palette, name: session.displayName, garments: state.garments)
                    case .you:      YouView(state: state, session: session, onSignOut: onSignOut)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                TabBar(
                    selection: $state.tab,
                    onCapture: { state.requestCapture() },
                    palette: state.palette
                )
            }
        }
        .animation(Motion.settle, value: state.tab)
        .sheet(isPresented: $state.isCapturing) {
            CaptureView(palette: state.palette) {
                Task { await state.reloadCaptures() }
            }
        }
        .sheet(isPresented: $state.showPaywall) {
            PaywallView(entitlements: state.entitlements, palette: state.palette)
        }
        .task { await state.entitlements.refresh() }
        .tint(state.palette.accent)
    }

    private var screenName: String {
        switch state.tab {
        case .closet: "closet"
        case .discover: "discover"
        case .outfits: "outfits"
        case .you: "you"
        }
    }
}
