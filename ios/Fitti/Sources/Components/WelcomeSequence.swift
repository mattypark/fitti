import SwiftUI
import FittiDesign

/// The opening sequence, authored entirely in code.
///
/// Every beat here is a spring or a shader uniform, which means it can be edited
/// by changing a number rather than by redrawing frames. That is the practical
/// argument for doing character animation this way: a hand-drawn or mesh-rigged
/// version of this would need re-authoring in a tool for every adjustment.
///
/// The beats, in order:
///   1. Fitti falls in from above and squashes on landing.
///   2. The impact scatters the colour blobs outward.
///   3. He wobbles back, overshooting.
///   4. The wordmark rises through the settle.
///   5. The tagline writes on, word by word.
///   6. The sign-in options slide up last.
struct WelcomeSequence<Content: View>: View {
    let palette: Palette
    /// The tagline, so the reveal always matches the copy. Deriving this rather
    /// than hardcoding a count is the difference between editing the string and
    /// silently losing its last word.
    let tagline: String
    @ViewBuilder var content: (WelcomeBeat) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = WelcomeBeat()

    private var wordCount: Int { tagline.split(separator: " ").count }

    var body: some View {
        content(beat)
            .task { await run() }
    }

    private func run() async {
        guard !reduceMotion else {
            beat = .finished(wordCount: wordCount)
            return
        }

        // 1. Drop. Stretched vertically on the way down — anticipation is what
        //    makes the landing land.
        withAnimation(.interpolatingSpring(stiffness: 170, damping: 14)) {
            beat.mascotDrop = 0
            beat.mascotStretch = 1.16
        }

        try? await Task.sleep(for: .milliseconds(340))

        // 2. Impact: squash hard and scatter the dots outward from underneath.
        withAnimation(.easeOut(duration: 0.09)) {
            beat.mascotStretch = 0.80
            beat.impact = 1
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
            beat.dotScatter = 1
        }

        try? await Task.sleep(for: .milliseconds(90))

        // 3. Recover, overshooting. Low damping on purpose — that wobble is the
        //    whole personality, and a critically damped version reads as stiff.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.34)) {
            beat.mascotStretch = 1
            beat.impact = 0
        }

        try? await Task.sleep(for: .milliseconds(120))

        // 4. Wordmark rises through the settle rather than after it, so the two
        //    motions overlap and the sequence doesn't feel like a queue.
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            beat.wordmark = 1
        }

        try? await Task.sleep(for: .milliseconds(180))

        // 5. Tagline writes on word by word — it's handwriting, so it should
        //    arrive the way handwriting does.
        for index in 0..<wordCount {
            withAnimation(.easeOut(duration: 0.28)) {
                beat.taglineWords = index + 1
            }
            try? await Task.sleep(for: .milliseconds(85))
        }

        try? await Task.sleep(for: .milliseconds(120))

        // 6. Controls last. Nothing is tappable until the app has introduced itself.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            beat.controls = 1
        }
    }
}

/// The animatable state of the opening. Each field drives one beat.
struct WelcomeBeat {
    /// Points above final position. Starts high, springs to 0.
    var mascotDrop: Double = -260
    /// Vertical scale. >1 stretched, <1 squashed.
    var mascotStretch: Double = 1.16
    /// 0...1 during the landing frame, for the ground ripple.
    var impact: Double = 0
    /// 0...1, pushes the colour blobs outward from the impact point.
    var dotScatter: Double = 0
    var wordmark: Double = 0
    var taglineWords: Int = 0
    var controls: Double = 0

    static func finished(wordCount: Int) -> WelcomeBeat {
        WelcomeBeat(mascotDrop: 0, mascotStretch: 1, impact: 0,
                    dotScatter: 1, wordmark: 1, taglineWords: wordCount, controls: 1)
    }
}

/// The tagline, revealed a word at a time.
struct WritingText: View {
    let text: String
    let visibleWords: Int
    let palette: Palette

    private var words: [String] { text.split(separator: " ").map(String.init) }

    var body: some View {
        // A flexible wrap rather than a fixed line break, so the reveal works at
        // any width without the words jumping between lines mid-animation.
        FlowLayout(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.fittiHand)
                    .foregroundStyle(palette.onGroundSoft)
                    .opacity(index < visibleWords ? 1 : 0)
                    .offset(y: index < visibleWords ? 0 : 6)
                    .blur(radius: index < visibleWords ? 0 : 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Minimal wrapping layout, rows centred.
///
/// `HStack` cannot wrap and a single `Text` cannot animate its words
/// independently, so the tagline needs its own layout. Rows are centred because
/// a left-ragged handwritten line under a centred wordmark reads as a mistake.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 2

    /// Groups subviews into rows that fit the available width.
    private func rows(_ subviews: Subviews, width: CGFloat) -> [[(Int, CGSize)]] {
        var result: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, !result[result.count - 1].isEmpty {
                result.append([])
                x = 0
            }
            result[result.count - 1].append((index, size))
            x += size.width + spacing
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = rows(subviews, width: width)
        let height = lines.reduce(into: CGFloat.zero) { total, row in
            total += (row.map(\.1.height).max() ?? 0) + lineSpacing
        }
        return CGSize(width: width, height: max(0, height - lineSpacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY

        for row in rows(subviews, width: bounds.width) {
            let rowWidth = row.reduce(into: CGFloat.zero) { $0 += $1.1.width + spacing } - spacing
            let rowHeight = row.map(\.1.height).max() ?? 0
            // Centre the row within the bounds.
            var x = bounds.minX + (bounds.width - rowWidth) / 2

            for (index, size) in row {
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }
}
