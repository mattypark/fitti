import UIKit
import CoreHaptics

/// Touch feedback.
///
/// Generators are prepared before use, because an unprepared generator has to
/// spin the Taptic Engine up on first fire and the feedback lands measurably late
/// — which is worse than none, since a haptic that arrives after the visual has
/// already moved reads as a glitch rather than as a response.
///
/// Restraint is the whole discipline here: haptics mean something only when they
/// are rare. Every call site below corresponds to a moment the user caused.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notice = UINotificationFeedbackGenerator()

    private var engine: CHHapticEngine?

    private init() {
        prepare()
        startEngine()
    }

    /// Call slightly before a haptic is likely — on gesture begin, on appear.
    func prepare() {
        light.prepare(); medium.prepare(); soft.prepare(); rigid.prepare()
        selection.prepare(); notice.prepare()
    }

    // MARK: - Simple feedback

    /// Moving between tabs, or any discrete change of selection.
    func select() { selection.selectionChanged() }

    /// A button that does something.
    func tap() { light.impactOccurred() }

    /// The shutter. Deliberately the heaviest thing in the app — capture is the
    /// one action the whole product exists for.
    func shutter() { rigid.impactOccurred(intensity: 1.0) }

    func success() { notice.notificationOccurred(.success) }
    func warning() { notice.notificationOccurred(.warning) }

    // MARK: - The blob

    /// Fitti being squished.
    ///
    /// A single tap is a click; this is two taps with a decaying second, which
    /// reads as something soft compressing and springing back rather than as a
    /// button. If Core Haptics is unavailable — older device, or the engine
    /// failed to start — it degrades to two plain impacts rather than silence.
    func squish() {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            soft.impactOccurred(intensity: 0.9)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                self?.soft.impactOccurred(intensity: 0.45)
            }
            return
        }

        let events = [
            // The compression: a short, firm hit.
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.85),
                .init(parameterID: .hapticSharpness, value: 0.35)
            ], relativeTime: 0),
            // The rebound: softer, blunter, and late enough to read as a separate
            // event rather than as one buzz.
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.45),
                .init(parameterID: .hapticSharpness, value: 0.10)
            ], relativeTime: 0.11)
        ]

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            soft.impactOccurred(intensity: 0.9)
        }
    }

    /// The welcome sequence's landing — Fitti hitting the ground.
    func land() {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            medium.impactOccurred(intensity: 1.0)
            return
        }

        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.55)
            ], relativeTime: 0),
            // A short settle after the impact, so it feels like weight arriving
            // rather than a single click.
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.30),
                .init(parameterID: .hapticSharpness, value: 0.05)
            ], relativeTime: 0.05, duration: 0.18)
        ]

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            medium.impactOccurred()
        }
    }

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()

        // The engine is stopped by the system on interruptions — a call, going to
        // the background. Without these it silently never works again.
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        engine?.playsHapticsOnly = true
        try? engine?.start()
    }
}
