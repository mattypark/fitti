import SwiftUI
import FittiDesign

/// Five slots, with capture as an oversized centre button.
///
/// Capture is the product's whole thesis — the fewest possible taps to save a
/// garment — so it is one tap from anywhere, and it is the largest target on
/// screen rather than one icon among equals.
struct TabBar: View {
    @Binding var selection: Tab
    var onCapture: () -> Void
    let palette: Palette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 0) {
            item(.closet, symbol: "square.grid.2x2", label: "Closet")
            item(.discover, symbol: "sparkle.magnifyingglass", label: "Discover")
            captureButton
            item(.outfits, symbol: "hanger", label: "Outfits")
            item(.you, symbol: "person", label: "You")
        }
        .padding(.horizontal, Space.xs)
        .padding(.top, Space.xs)
        .background {
            palette.groundSunk
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: Tab, symbol: String, label: String) -> some View {
        Button {
            guard selection != tab else { return }
            Haptics.shared.select()
            withAnimation(Motion.respecting(Motion.snappy, reduceMotion: reduceMotion)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                // Selection is carried by weight and opacity, not by a shape
                // behind the icon. One decorative form doing five different jobs
                // is what made the app read as assembled from parts.
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: selection == tab ? .semibold : .regular))
                    .frame(height: 34)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selection == tab ? palette.onGround : palette.onGroundFaint)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Space.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.squash)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
    }

    private var captureButton: some View {
        Button {
            Haptics.shared.tap()
            onCapture()
        } label: {
            ZStack {
                BlobShape(seed: "capture".paletteSeed, wobble: 0.14)
                    .fill(Fixed.yellow)
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Fixed.ink)
            }
            .frame(width: 62, height: 62)
            .offset(y: -10)
        }
        .buttonStyle(.squash)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Add clothes")
    }
}
