import SwiftUI
import FittiDesign

/// The rainbow dots: two to four coloured blobs drifting behind a screen's
/// content.
///
/// Seeded from the screen's name, so Closet always has Closet's dots in Closet's
/// places. They are scenery, not decoration that reshuffles — the stability is
/// what makes them feel like part of the room.
struct BlobDots: View {
    let screen: String
    var count: Int = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: Double = 0

    private struct Dot {
        let seed: UInt64
        let color: Color
        let position: UnitPoint
        let size: CGFloat
        let speed: Double
    }

    private var dots: [Dot] {
        var generator = SplitMix64(seed: screen.paletteSeed)
        let palette = DotPalette.all
        return (0..<count).map { index in
            let seed = generator.next()
            let color = palette[Int(generator.next() % UInt64(palette.count))]
            // Kept away from the vertical centre so dots never sit under the
            // content people are actually reading.
            let x = 0.06 + Double(generator.next() % 880) / 1000
            let y = 0.04 + Double(generator.next() % 920) / 1000
            let size = 14 + CGFloat(generator.next() % 32)
            let speed = 14 + Double(generator.next() % 12)
            return Dot(seed: seed, color: color,
                       position: UnitPoint(x: x, y: y),
                       size: size, speed: speed)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                    BlobShape(seed: dot.seed, wobble: 0.22, phase: drift)
                        .fill(dot.color)
                        .frame(width: dot.size, height: dot.size)
                        .position(x: dot.position.x * geometry.size.width,
                                  y: dot.position.y * geometry.size.height)
                        .offset(y: reduceMotion ? 0 : sin(drift * 2 * .pi) * dot.speed * 0.3)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                drift = 1
            }
        }
    }
}
