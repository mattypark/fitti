import SwiftUI
import FittiDesign

/// A waterfall. Each item drops into whichever column is currently shortest, so a
/// belt can sit beside a coat without inheriting the coat's height.
///
/// `LazyVGrid` cannot do this. Its rows align to the tallest cell, which left a
/// band of dead space beside every short garment — and that ragged, evenly-gapped
/// whitespace is a large part of what makes a grid read as generated rather than
/// curated. Alta and Cosmos are both two-up waterfalls on mobile for the same
/// reason: the varying silhouette is the composition.
///
/// Packing is arithmetic on the declared aspect ratios — no measurement pass and
/// no per-cell `GeometryReader` — so it stays cheap as the closet grows. The
/// running totals are in aspect-ratio units rather than points, which is valid
/// precisely because every column is the same width.
struct StaggeredGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var columns: Int = 2
    var spacing: CGFloat = Space.sm
    /// Width ÷ height, the same convention as `View.aspectRatio(_:contentMode:)`.
    let aspectRatio: (Item) -> CGFloat
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(packed().enumerated()), id: \.offset) { _, column in
                LazyVStack(spacing: spacing) {
                    ForEach(column) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// Greedy shortest-column packing, in source order. Ties go left, so the first
    /// row reads left-to-right like a list rather than arriving scrambled.
    private func packed() -> [[Item]] {
        let count = max(1, columns)
        var buckets = Array(repeating: [Item](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)

        for item in items {
            let shortest = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            buckets[shortest].append(item)
            // Height per unit width is the reciprocal of the aspect ratio.
            heights[shortest] += 1 / max(0.01, aspectRatio(item))
        }
        return buckets
    }
}
