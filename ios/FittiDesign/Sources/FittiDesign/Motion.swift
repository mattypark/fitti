import SwiftUI

/// Every animation in Fitti is a spring. No duration-and-easing curves anywhere.
///
/// The reason is interruption: a spring interrupted mid-flight continues from its
/// current velocity, so a user who taps a tab twice in quick succession sees one
/// continuous motion. A curve restarts, which reads as a stutter — and this app is
/// built to be tapped fast.
///
/// Requires `CADisableMinimumFrameDurationOnPhone = true` in Info.plist. Without it
/// ProMotion caps the app at 60fps and every spring below looks like a cheaper version
/// of itself.
public enum Motion {
    /// The mascot, and nothing else. Visibly overshoots — that overshoot is the
    /// jello the brand is built on, and it only reads as alive because nothing
    /// else in the app does it. Spring bounce on ordinary interface chrome reads
    /// dated; reserve it.
    public static let blob = Animation.spring(response: 0.55, dampingFraction: 0.62)

    /// Buttons, toggles, chips. Fast, barely overshoots.
    public static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.86)

    /// Sheets and navigation. Critically damped — no overshoot at all, because content
    /// arriving with a bounce is harder to read.
    public static let settle = Animation.spring(response: 0.45, dampingFraction: 1.0)

    /// Honors Reduce Motion by collapsing to a crossfade rather than removing feedback
    /// entirely — a control that responds to a tap with nothing at all feels broken.
    public static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : animation
    }
}

/// The house press. The mascot does it on launch and the shutter does it on every
/// shot — one physical language across the whole app.
public struct SquashButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Uniform, and no overshoot. The asymmetric squash reads as a
            // character trait, which is right for the mascot and wrong for
            // every button in the app.
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.respecting(Motion.snappy, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == SquashButtonStyle {
    static var squash: SquashButtonStyle { SquashButtonStyle() }
}
