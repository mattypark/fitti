import SwiftUI
import FittiDesign

/// An irregular blob. The whole brand rests on this shape, so it is deliberately
/// never a circle: each control point sits at a different radius, and no two
/// sides match.
///
/// The wobble is generated from a seed rather than randomly, so a given blob is
/// the same blob on every launch. A dot that jumps to a new silhouette each time
/// the screen appears reads as a glitch; one that keeps its shape reads as an
/// object.
struct BlobShape: Shape {
    /// Determines the silhouette. Same seed, same blob, forever.
    var seed: UInt64
    /// How far radii deviate from the mean, 0...1. Around 0.18 reads as "soft
    /// jelly"; past 0.35 it starts to look like a splat.
    var wobble: Double = 0.18
    /// Drives the idle wobble. Animate this and the blob breathes.
    var phase: Double = 0
    /// Number of control points. Six is the sweet spot — fewer reads as a
    /// rounded polygon, more averages back out into a circle.
    var points: Int = 6

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2

        var generator = SplitMix64(seed: seed)
        // Per-point radius offset and a per-point phase shift, so the blob
        // wobbles unevenly rather than pulsing like a balloon.
        let offsets: [(radius: Double, drift: Double)] = (0..<points).map { _ in
            let r = Double(generator.next() % 1000) / 1000
            let d = Double(generator.next() % 1000) / 1000
            return (r, d)
        }

        var vertices: [CGPoint] = []
        for index in 0..<points {
            let angle = (Double(index) / Double(points)) * 2 * .pi
            let offset = offsets[index]
            // Static irregularity, plus a slow breath.
            let deviation = (offset.radius - 0.5) * 2 * wobble
                + sin(phase * 2 * .pi + offset.drift * 2 * .pi) * wobble * 0.35
            let radius = baseRadius * (1 + deviation)
            vertices.append(CGPoint(x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius))
        }

        return Path { path in
            guard vertices.count > 2 else { return }
            // Catmull-Rom through the vertices, converted to cubic Béziers, so
            // the outline is smooth and closed with no visible seam at the start
            // point — a straight-line polygon would kill the jello read instantly.
            path.move(to: vertices[0])
            for index in 0..<vertices.count {
                let p0 = vertices[(index - 1 + vertices.count) % vertices.count]
                let p1 = vertices[index]
                let p2 = vertices[(index + 1) % vertices.count]
                let p3 = vertices[(index + 2) % vertices.count]

                let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                                       y: p1.y + (p2.y - p0.y) / 6)
                let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                                       y: p2.y - (p3.y - p1.y) / 6)
                path.addCurve(to: p2, control1: control1, control2: control2)
            }
            path.closeSubpath()
        }
    }
}
