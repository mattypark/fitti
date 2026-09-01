import SwiftUI
import FittiDesign

struct RootView: View {
    let session: Session
    var onSignOut: () -> Void

    @State private var state = AppState()

    var body: some View {
        ZStack(alignment: .bottom) {
            // One butter ground for everybody. The personal hue is the accent.
            state.palette.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch state.tab {
                    case .closet:   ClosetView(state: state)
                    case .discover: DiscoverView(isOnline: state.reachability.isOnline)
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
        .animation(Motion.snappy, value: state.tab)
        .sheet(isPresented: $state.isCapturing) {
            CaptureView(palette: state.palette) {
                Task { await state.reloadCaptures() }
            }
        }
        .sheet(isPresented: $state.showAIConsent) {
            AIConsentView(palette: state.palette) { granted in
                AIConsent.isGranted = granted
                state.showAIConsent = false
                state.isCapturing = true
            }
        }
        .sheet(isPresented: $state.showPaywall) {
            PaywallView(entitlements: state.entitlements, palette: state.palette)
        }
        .task { await state.entitlements.refresh() }
        .tint(state.palette.accent)
    }
}
