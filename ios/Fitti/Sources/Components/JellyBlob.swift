import SwiftUI
import FittiDesign

/// The house material. Every coloured form in Fitti is a blob of the same stuff,
/// lit by the same key light from the upper left.
///
/// A flat fill is what made the closet read as off-shape matte colours rather
/// than as objects — the mascot looked like clay and nothing else did, because
/// his rendering is baked into a PNG and every procedural shape had none. Four
/// cheap layers close that gap:
///
/// - a **subsurface ramp**, light gathering at the crown and pooling darker at
///   the base, built in OKLCH so moving lightness does not drag the hue,
/// - a **specular** offset toward the key light, which is the single thing that
///   makes a surface read as wet rather than as paper,
/// - a **rim** where the ground bounces back up the far edge, which is what
///   separates the blob from the ground behind it,
/// - a **coloured glow** underneath, so it sits *in* the scene rather than on it.
///
/// All gradients and one shadow. No `.blur()` on the shape: these sit in scroll
/// views on an animated path, where a blur costs a full offscreen pass per frame.
struct JellyBlob<S: Shape>: View {
    let shape: S
    /// The form's own colour, in the same OKLCH the palette is built from.
    let base: OKLCH
    /// Radius of the coloured glow. Scale it with the blob — a 38pt meter with a
    /// 24pt glow looks like it is on fire.
    var glow: CGFloat = 18
    /// Ghosts and disabled states keep the silhouette and lose the light.
    var isFlat: Bool = false

    var body: some View {
        shape
            .fill(isFlat ? AnyShapeStyle(Color(base)) : AnyShapeStyle(subsurface))
            .overlay {
                if !isFlat {
                    shape.fill(specular).blendMode(.screen)
                }
            }
            .overlay {
                if !isFlat {
                    // Clipped back to the silhouette so only the inner half of
                    // the stroke survives. An unclipped stroke straddles the
                    // path, and the outer half reads as a drawn outline rather
                    // than as light catching an edge — which is the difference
                    // between a jelly and a sticker.
                    shape.stroke(rim, lineWidth: 2.6)
                        .clipShape(shape)
                        .blendMode(.plusLighter)
                }
            }
            // Composite the three layers before the shadow, or the glow is cast
            // by the flat fill alone and the highlight sits outside it.
            .compositingGroup()
            .shadow(color: isFlat ? .clear : Color(deepened(0.06)).opacity(0.45),
                    radius: glow, x: 0, y: glow * 0.38)
    }

    // MARK: - The material

    /// Crown to base. The deep end also gains a little chroma, which is what real
    /// translucent material does — the light that survives the longest path
    /// through it is the most saturated.
    private var subsurface: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(lightened(0.13)), location: 0.00),
            .init(color: Color(base),            location: 0.50),
            .init(color: Color(deepened(0.12)),  location: 1.00),
        ], startPoint: .top, endPoint: .bottom)
    }

    /// Offset up and left, and soft-edged. A hard-edged highlight reads as a
    /// sticker; this one reads as a wet surface catching a window.
    private var specular: EllipticalGradient {
        EllipticalGradient(stops: [
            .init(color: .white.opacity(0.66), location: 0.00),
            .init(color: .white.opacity(0.20), location: 0.42),
            .init(color: .white.opacity(0.00), location: 1.00),
        ], center: UnitPoint(x: 0.33, y: 0.20),
           startRadiusFraction: 0, endRadiusFraction: 0.58)
    }

    /// Bright where the key light grazes the top-left edge, and bright again at
    /// the bottom-right where the ground bounces back up. Dark in between.
    private var rim: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.42), location: 0.00),
            .init(color: .white.opacity(0.04), location: 0.38),
            .init(color: .white.opacity(0.00), location: 0.62),
            .init(color: .white.opacity(0.26), location: 1.00),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func lightened(_ delta: Double) -> OKLCH {
        OKLCH(min(0.985, base.lightness + delta), base.chroma * 0.82, base.hue).gamutMapped()
    }

    private func deepened(_ delta: Double) -> OKLCH {
        OKLCH(max(0.05, base.lightness - delta), base.chroma * 1.08, base.hue).gamutMapped()
    }
}

extension View {
    /// A jelly surface behind a control, so a primary button is made of the same
    /// material as the app rather than pasted on top of it. A flat brand-yellow
    /// rectangle beside a glossy blob is the join showing.
    func jellySurface<S: Shape>(_ shape: S,
                                base: OKLCH = Fixed.yellowPigment,
                                glow: CGFloat = 12) -> some View {
        background { JellyBlob(shape: shape, base: base, glow: glow) }
    }
}

/// A slow, uneven breath shared by every blob that wants one.
///
/// The clock lives per blob rather than per screen on purpose: a `TimelineView`
/// wrapped around the whole grid would invalidate the grid — packing, columns and
/// all — sixty times a second, where one wrapped around a single tile invalidates
/// only that tile, and a tile scrolled out of a lazy stack does not exist to tick.
struct LiquidBlob: View {
    var seed: UInt64
    var base: OKLCH
    var wobble: Double = 0.14
    /// Cycles per second. Deliberately far below anything you would call an
    /// animation — you should notice it only if you stare.
    var rate: Double = 0.055
    var glow: CGFloat = 18

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: scenePhase != .active || reduceMotion)) { timeline in
            // Offset by the seed so no two blobs breathe in step. A grid that
            // pulses in unison reads as a loading screen.
            let drift = Double(seed % 997) / 997
            let phase = reduceMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate * rate + drift

            JellyBlob(shape: BlobShape(seed: seed, wobble: wobble, phase: phase),
                      base: base,
                      glow: glow)
        }
    }
}
