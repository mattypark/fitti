import SwiftUI
import FittiDesign

/// How Fitti feels about what he's looking at.
///
/// Ordered, because it is derived from a score and the ordering is what lets it
/// blend rather than switch.
enum Mood: Int, CaseIterable, Comparable, Sendable {
    case asleep, unsure, neutral, pleased, delighted

    static func < (a: Mood, b: Mood) -> Bool { a.rawValue < b.rawValue }

    /// From an outfit score, 0...1.
    init(score: Double) {
        switch score {
        case ..<0.35: self = .unsure
        case ..<0.55: self = .neutral
        case ..<0.78: self = .pleased
        default: self = .delighted
        }
    }
}

/// Fitti, drawn rather than photographed.
///
/// The original art is cropped at two edges — it was composed as an app icon,
/// emerging from a corner — so it can never show a whole character. Drawing him
/// solves that and buys something bigger: the face becomes animatable. A PNG has
/// one expression forever.
///
/// The body keeps the source art's shading language: a warm radial gradient with
/// the light high-left, a soft rim, and a specular pip. Close enough that the
/// icon and the character read as the same creature.
struct FittiCharacter: View {
    var size: CGFloat = 160
    var mood: Mood = .pleased
    /// 0...1 liquid fill, for the closet meter.
    var level: Double = 0
    /// Which way he's looking, -1...1. Used to glance at an outfit beside him.
    var gaze: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var blink = false
    @State private var squash: Double = 0
    @State private var touch: CGPoint?

    private let seed = "fitti-body".paletteSeed

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                body(at: time)
                face
            }
            .frame(width: size, height: size)
            // Volume-preserving squash, same rule as the shader.
            .scaleEffect(x: 1 + squash * 0.10, y: 1 - squash * 0.12, anchor: .bottom)
            .scaleEffect(breathe ? 1.018 : 0.994, anchor: .bottom)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    touch = value.location
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { squash = 1 }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.32)) { squash = 0 }
                }
        )
        .onAppear(perform: startIdle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fitti, looking \(moodDescription)")
    }

    // MARK: - Body

    private func body(at time: TimeInterval) -> some View {
        let wobble = reduceMotion ? 0 : sin(time * 1.5) * 0.5 + 0.5

        return ZStack {
            // Base shape. The wobble drives the blob's phase, so the silhouette
            // itself breathes rather than the whole view just scaling.
            FittiSilhouette(phase: wobble)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.87, blue: 0.42),
                            Color(red: 0.98, green: 0.76, blue: 0.16),
                            Color(red: 0.88, green: 0.60, blue: 0.07)
                        ],
                        center: UnitPoint(x: 0.32, y: 0.22),
                        startRadius: size * 0.02,
                        endRadius: size * 0.78
                    )
                )

            // Liquid fill, when the closet meter is driving him.
            if level > 0 {
                FittiSilhouette(phase: wobble)
                    .fill(Color(red: 0.95, green: 0.55, blue: 0.10).opacity(0.55))
                    .mask(alignment: .bottom) {
                        GeometryReader { geometry in
                            Rectangle()
                                .frame(height: geometry.size.height * level)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
            }

            // Rim light along the lower-right, which is what sells the volume.
            FittiSilhouette(phase: wobble)
                .stroke(
                    LinearGradient(
                        colors: [.clear, Color(red: 1, green: 0.93, blue: 0.62).opacity(0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.02
                )
                .blur(radius: size * 0.012)

            // Specular pip, high-left to match the light in the gradient.
            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.16, height: size * 0.11)
                .rotationEffect(.degrees(-24))
                .offset(x: -size * 0.16, y: -size * 0.24)
                .blur(radius: size * 0.02)
        }
    }

    // MARK: - Face

    private var face: some View {
        let lookX = gaze * size * 0.035

        return VStack(spacing: size * 0.055) {
            HStack(spacing: size * 0.16) {
                Eye(mood: mood, isBlinking: blink)
                Eye(mood: mood, isBlinking: blink)
            }
            Mouth(mood: mood)
                .stroke(Fixed.ink, style: StrokeStyle(lineWidth: size * 0.026, lineCap: .round))
                .frame(width: size * 0.20, height: size * 0.09)
        }
        .frame(width: size * 0.54)
        .offset(x: lookX, y: size * 0.03)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: mood)
        .animation(.easeInOut(duration: 0.09), value: blink)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: gaze)
    }

    private var moodDescription: String {
        switch mood {
        case .asleep: "sleepy"
        case .unsure: "unsure"
        case .neutral: "neutral"
        case .pleased: "pleased"
        case .delighted: "delighted"
        }
    }

    private func startIdle() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathe = true
        }
        Task { await blinkLoop() }
    }

    /// Blinks at irregular intervals. A fixed cadence reads as a metronome, which
    /// is the fastest way to make something feel mechanical.
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.6...6.5)))
            guard !reduceMotion else { continue }
            blink = true
            try? await Task.sleep(for: .milliseconds(110))
            blink = false
        }
    }
}

/// One eye. Shape carries the mood, since a curve reads as feeling far faster
/// than any colour or motion does.
private struct Eye: View {
    let mood: Mood
    let isBlinking: Bool

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            Path { path in
                if isBlinking || mood == .asleep || mood >= .pleased {
                    // A closed upward arc: the classic content eye.
                    path.move(to: CGPoint(x: 0, y: w * 0.62))
                    path.addQuadCurve(
                        to: CGPoint(x: w, y: w * 0.62),
                        control: CGPoint(x: w * 0.5, y: mood == .delighted ? -w * 0.12 : w * 0.06)
                    )
                } else if mood == .unsure {
                    // Flatter, slightly lowered — reads as squinting at something.
                    path.move(to: CGPoint(x: 0, y: w * 0.52))
                    path.addQuadCurve(to: CGPoint(x: w, y: w * 0.46),
                                      control: CGPoint(x: w * 0.5, y: w * 0.30))
                } else {
                    path.addEllipse(in: CGRect(x: w * 0.18, y: w * 0.10,
                                               width: w * 0.64, height: w * 0.68))
                }
            }
            .stroke(Fixed.ink, style: StrokeStyle(lineWidth: w * 0.17, lineCap: .round))
            .background {
                if mood == .neutral && !isBlinking {
                    Ellipse()
                        .fill(Fixed.ink)
                        .frame(width: w * 0.64, height: w * 0.68)
                        .offset(x: w * 0.18, y: w * 0.10)
                }
            }
        }
        .frame(width: 18, height: 18)
        .scaleEffect(isBlinking ? CGSize(width: 1, height: 0.35) : CGSize(width: 1, height: 1))
    }
}

/// The mouth. Same principle: curvature is the whole signal.
private struct Mouth: Shape {
    let mood: Mood

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        switch mood {
        case .delighted:
            // Open, wide — the only one that isn't a single stroke.
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: h * 1.9))
        case .pleased:
            path.move(to: CGPoint(x: 0, y: h * 0.1))
            path.addQuadCurve(to: CGPoint(x: w, y: h * 0.1), control: CGPoint(x: w / 2, y: h * 1.1))
        case .neutral:
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.5))
        case .unsure:
            // Asymmetric, which is what makes it read as doubt rather than sadness.
            path.move(to: CGPoint(x: w * 0.1, y: h * 0.7))
            path.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.45),
                              control: CGPoint(x: w * 0.5, y: h * 0.2))
        case .asleep:
            path.move(to: CGPoint(x: w * 0.3, y: h * 0.5))
            path.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.5),
                              control: CGPoint(x: w * 0.5, y: h * 0.9))
        }
        return path
    }
}
