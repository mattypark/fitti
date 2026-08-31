import SwiftUI
import FittiDesign

/// Home.
///
/// The week runs across the top, because getting dressed is a daily rhythm rather
/// than a browse — you are almost always answering "what do I wear today", and
/// occasionally "what did I wear on Tuesday". Weather sits next to the greeting
/// because it is the single biggest constraint on the answer.
///
/// Everything is shown on a body. A stack of thumbnails tells you what you own; a
/// figure tells you what you'd look like.
struct OutfitsView: View {
    let palette: Palette
    var name: String?

    @State private var days = MockWeek.days()
    @State private var selected: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let forecast = Forecast.mock

    private var selectedDay: ClosetDay? {
        days.first { $0.id == selected } ?? days.first(where: \.isToday) ?? days.last
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                streakBar
                weekStrip
                askBar
                greeting
                todaysLook
                suggestions
            }
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .onAppear { if selected == nil { selected = days.first(where: \.isToday)?.id } }
    }

    // MARK: - Streak

    private var streakBar: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "flame.fill")
                .foregroundStyle(palette.accent)
            Text("3")
                .font(.fittiHeadline)
                .monospacedDigit()
                .foregroundStyle(palette.onGround)
            Text("days logged")
                .font(.fittiCallout)
                .foregroundStyle(palette.onGroundSoft)
            Spacer()
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("3 day logging streak")
    }

    // MARK: - Week

    private var weekStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Space.xs) {
                ForEach(days) { day in
                    dayColumn(day)
                }
            }
            .padding(.horizontal, Space.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func dayColumn(_ day: ClosetDay) -> some View {
        let isSelected = day.id == selectedDay?.id

        return Button {
            withAnimation(Motion.respecting(Motion.blob, reduceMotion: reduceMotion)) {
                selected = day.id
            }
        } label: {
            VStack(spacing: Space.xxs) {
                Text(day.weekdayLabel)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(isSelected ? palette.onGround : palette.onGroundSoft)

                Text(day.dayNumber)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? palette.onGround : palette.onGroundSoft)
                    .frame(width: 26, height: 26)
                    .background {
                        if day.isToday {
                            BlobShape(seed: "today".paletteSeed, wobble: 0.2)
                                .fill(Fixed.yellow)
                        }
                    }

                Group {
                    if let outfit = day.outfit {
                        OutfitFigure(outfit: outfit, height: 74)
                    } else {
                        GhostFigure(height: 74, palette: palette)
                    }
                }
                .frame(width: 46)

                // The selected day gets an underline rather than a filled chip, so
                // the figures above stay the loudest thing in the row.
                Capsule()
                    .fill(isSelected ? palette.onGround : .clear)
                    .frame(width: 26, height: 2)
            }
            .padding(.vertical, Space.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.squash)
        .accessibilityLabel("\(day.weekdayLabel) \(day.dayNumber)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Ask

    private var askBar: some View {
        Button {
            // Wired to the stylist in stage 10.
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: "sparkles")
                Text("Ask Fitti")
                    .font(.fittiHeadline)
                Spacer()
            }
            .foregroundStyle(palette.onGround)
            .padding(.horizontal, Space.md)
            .frame(height: 50)
            .background(palette.groundLift,
                        in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        }
        .buttonStyle(.squash)
        .padding(.horizontal, Space.gutter)
    }

    // MARK: - Greeting + weather

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(salutation)
                    .font(.fittiTitle)
                    .foregroundStyle(palette.onGround)
                Text(forecast.advice)
                    .font(.fittiHand)
                    .foregroundStyle(palette.onGroundSoft)
            }

            Spacer()

            HStack(spacing: Space.xs) {
                Image(systemName: forecast.symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Fixed.yellow)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(forecast.temperature)°")
                        .font(.fittiHeadline)
                        .monospacedDigit()
                        .foregroundStyle(palette.onGround)
                    Text("H:\(forecast.high)° L:\(forecast.low)°")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(palette.onGroundSoft)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(forecast.temperature) degrees, \(forecast.condition)")
        }
        .padding(.horizontal, Space.gutter)
    }

    private var salutation: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = switch hour {
        case ..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
        return name.map { "\(part), \($0)" } ?? part
    }

    // MARK: - The day's look

    @ViewBuilder
    private var todaysLook: some View {
        if let day = selectedDay, let outfit = day.outfit {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.xs) {
                    Circle()
                        .fill(Fixed.yellow)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Text(String(outfit.wearer.prefix(1)))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Fixed.ink)
                        }
                    Text("\(outfit.wearer) logged this")
                        .font(.fittiCallout)
                        .foregroundStyle(palette.onGroundSoft)
                }

                HStack(alignment: .bottom, spacing: Space.lg) {
                    VStack(spacing: Space.xs) {
                        OutfitFigure(outfit: outfit, height: 230)
                        Text(outfit.wearer)
                            .font(.fittiHeadline)
                            .foregroundStyle(palette.onGround)
                        Label(outfit.place, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onGroundSoft)
                    }
                    Spacer()
                }

                if let note = outfit.note {
                    Text(note)
                        .font(.fittiHand)
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, Space.gutter)
        } else {
            emptyDay
        }
    }

    private var emptyDay: some View {
        VStack(spacing: Space.sm) {
            Mascot(size: 96)
            Text(selectedDay?.isFuture == true
                 ? "nothing planned yet"
                 : "you didn't log this day")
                .font(.fittiHand)
                .foregroundStyle(palette.onGroundSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    // MARK: - Suggestions

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Rectangle().fill(palette.onGroundSoft.opacity(0.25)).frame(height: 1)
                Text("TODAY'S SUGGESTIONS")
                    .fittiLabelStyle()
                    .foregroundStyle(palette.onGroundSoft)
                    .fixedSize()
                Rectangle().fill(palette.onGroundSoft.opacity(0.25)).frame(height: 1)
            }

            ScrollView(.horizontal) {
                HStack(spacing: Space.md) {
                    ForEach(MockSuggestions.all) { outfit in
                        VStack(spacing: Space.xs) {
                            OutfitFigure(outfit: outfit, height: 170)
                                .frame(width: 106)
                                .padding(.vertical, Space.sm)
                                .background(palette.groundLift,
                                            in: RoundedRectangle(cornerRadius: Radius.tile,
                                                                 style: .continuous))
                            Text(outfit.note ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.onGroundSoft)
                                .frame(width: 106)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Space.gutter)
        }
        .padding(.horizontal, Space.gutter)
    }
}

enum MockSuggestions {
    static let all: [WornOutfit] = [
        .init(wearer: "You", place: "", topHue: 85, bottomHue: 250, shoeHue: 30,
              note: "warm enough for this"),
        .init(wearer: "You", place: "", topHue: 220, bottomHue: 60, shoeHue: 195,
              note: "you haven't worn these"),
        .init(wearer: "You", place: "", topHue: 15, bottomHue: 250, shoeHue: 25,
              note: "goes with the coat"),
    ]
}
