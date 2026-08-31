import SwiftUI

/// Fitti's actual outline.
///
/// Hand-authored rather than seeded from noise. A random blob is a different
/// creature every time you change the seed; a character needs one silhouette
/// people recognise. These points trace the original artwork: a broad rounded
/// mass, a distinct bump at the upper right, a slight shoulder on the left, and
/// a wide flat-ish base he sits on.
///
/// Radii are fractions of half the frame, angles are degrees clockwise from the
/// top. Editing the character means editing this table and nothing else.
struct FittiSilhouette: Shape {
    /// Drives the idle wobble, 0...1.
    var phase: Double = 0
    /// How much the outline breathes. 0 freezes it.
    var wobble: Double = 0.035

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    /// (angle°, radius, wobbleWeight) — weight lets some lobes move more than
    /// others, which is what stops the breathing looking like a pulsing balloon.
    private static let outline: [(Double, Double, Double)] = [
        (  0, 0.86, 1.0),   // crown
        ( 34, 0.98, 1.4),   // the bump — his most recognisable feature
        ( 66, 0.86, 0.8),
        ( 96, 0.93, 1.1),   // right cheek, wide
        (130, 0.95, 0.7),
        (162, 0.88, 0.5),   // base, right side
        (196, 0.86, 0.5),   // base, left side — flatter, he sits on this
        (228, 0.94, 0.7),
        (262, 0.96, 1.1),   // left cheek
        (292, 0.83, 0.9),   // left shoulder, tucked in
        (326, 0.90, 1.2)
    ]

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let unit = min(rect.width, rect.height) / 2

        let vertices: [CGPoint] = Self.outline.enumerated().map { index, point in
            let (degrees, radius, weight) = point
            // Each lobe breathes on its own phase offset, so the whole outline
            // never expands in unison.
            let breath = sin(phase * 2 * .pi + Double(index) * 0.9) * wobble * weight
            let r = unit * (radius + breath)
            // -90 so 0° is the top rather than the right.
            let radians = (degrees - 90) * .pi / 180
            return CGPoint(x: centre.x + cos(radians) * r,
                           y: centre.y + sin(radians) * r)
        }

        // Catmull-Rom through the points, as cubic Béziers. A straight-line
        // polygon through these would read as a gem, not a blob.
        return Path { path in
            path.move(to: vertices[0])
            for index in vertices.indices {
                let count = vertices.count
                let p0 = vertices[(index - 1 + count) % count]
                let p1 = vertices[index]
                let p2 = vertices[(index + 1) % count]
                let p3 = vertices[(index + 2) % count]

                path.addCurve(
                    to: p2,
                    control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                    control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
                )
            }
            path.closeSubpath()
        }
    }
}
