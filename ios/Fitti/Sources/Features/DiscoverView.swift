import SwiftUI
import FittiDesign

/// The shopping grid.
///
/// Tiles show the garment alone — no model, no room, no styling. That is the
/// whole premise: you are looking at clothes, not at a photoshoot. Press and hold
/// any tile and the on-model shot fades in under your finger, then snaps back
/// when you let go.
///
/// This screen runs on paper rather than the user's ground colour, so the clothes
/// are the only colour on it.
struct DiscoverView: View {
    /// The shop is the one part of Fitti that needs a network.
    var isOnline: Bool = true

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Space.sm)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("DISCOVER")
                    .fittiTitleStyle()
                    .foregroundStyle(Fixed.ink)

                Text("Hold a piece to see it worn")
                    .font(.fittiCallout)
                    .foregroundStyle(Fixed.ink.opacity(0.55))

                if !isOnline {
                    StateView(kind: .offline,
                              message: "no signal — I'll bring the shop back\nwhen you're online again",
                              foreground: Fixed.ink)
                } else if MockCatalog.listings.isEmpty {
                    StateView(kind: .empty,
                              message: "nothing new in here today",
                              foreground: Fixed.ink)
                } else {
                    LazyVGrid(columns: columns, spacing: Space.sm) {
                        ForEach(MockCatalog.listings) { listing in
                            ListingTile(listing: listing)
                        }
                    }
                    .padding(.top, Space.xs)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ListingTile: View {
    let listing: MockListing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var peeking = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Color.black.opacity(0.035))

                // The garment, alone.
                BlobShape(seed: listing.name.paletteSeed, wobble: 0.15)
                    .fill(Color(OKLCH(0.66, 0.14, listing.hue)))
                    .padding(26)
                    .opacity(peeking ? 0 : 1)

                // The same piece, worn. Some listings genuinely have no on-model
                // shot, so holding those does nothing rather than showing a
                // placeholder — an empty state would be worse than no state.
                if let wornHue = listing.wornHue {
                    WornPreview(hue: wornHue, seed: listing.name.paletteSeed)
                        .opacity(peeking ? 1 : 0)
                }
            }
            .aspectRatio(0.82, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .scaleEffect(peeking ? 0.97 : 1)
            .animation(Motion.respecting(Motion.blob, reduceMotion: reduceMotion), value: peeking)
            .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 40) {
                // Fires on completion; the pressing closure below drives the peek.
            } onPressingChanged: { pressing in
                guard listing.wornHue != nil else { return }
                peeking = pressing
                if pressing {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(listing.brand)
                    .fittiLabelStyle()
                    .foregroundStyle(Fixed.ink.opacity(0.5))
                Text(listing.name)
                    .font(.fittiCallout.weight(.medium))
                    .foregroundStyle(Fixed.ink)
                Text(listing.price)
                    .font(.fittiCallout)
                    .foregroundStyle(Fixed.ink.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.name) by \(listing.brand), \(listing.price)")
        .accessibilityHint(listing.wornHue == nil ? "" : "Touch and hold to see it worn")
    }
}

/// Stand-in for an on-model photograph: the garment blob with a figure behind it.
private struct WornPreview: View {
    let hue: Double
    let seed: UInt64

    var body: some View {
        ZStack {
            Color(OKLCH(0.88, 0.02, hue))
            VStack(spacing: -6) {
                Circle()
                    .fill(Color(OKLCH(0.72, 0.05, 60)))
                    .frame(width: 30, height: 30)
                BlobShape(seed: seed, wobble: 0.1)
                    .fill(Color(OKLCH(0.62, 0.14, hue)))
                    .frame(width: 86, height: 104)
            }
        }
    }
}
