import Foundation
import SwiftUI
import FittiDesign

/// A day on the week strip, and whatever was worn on it.
struct ClosetDay: Identifiable {
    let id = UUID()
    let date: Date
    let outfit: WornOutfit?

    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isFuture: Bool { date > Date() && !isToday }

    var weekdayLabel: String {
        date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }
    var dayNumber: String {
        date.formatted(.dateTime.day())
    }
}

/// An outfit as worn — the pieces, and who wore it.
struct WornOutfit: Identifiable, Hashable {
    let id = UUID()
    let wearer: String
    let place: String
    /// Hues of the pieces, top to bottom, used to draw the figure.
    let topHue: Double
    let bottomHue: Double
    let shoeHue: Double
    let note: String?
}

enum MockWeek {
    /// A week centred on today, with outfits logged up to now and nothing after —
    /// the future is genuinely empty, which is what makes the strip meaningful.
    static func days() -> [ClosetDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }

        let logged: [Int: WornOutfit] = [
            0: WornOutfit(wearer: "You", place: "Home", topHue: 220, bottomHue: 250,
                          shoeHue: 30, note: "rained all day"),
            1: WornOutfit(wearer: "You", place: "School", topHue: 85, bottomHue: 60,
                          shoeHue: 195, note: nil),
            2: WornOutfit(wearer: "You", place: "Practice", topHue: 15, bottomHue: 250,
                          shoeHue: 195, note: "wore this to school"),
        ]

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let isPastOrToday = date <= today
            return ClosetDay(date: date, outfit: isPastOrToday ? logged[offset] : nil)
        }
    }
}

/// Today's weather. Real forecasting arrives with the outfit engine; the shape is
/// what the UI needs to be built against.
struct Forecast {
    let temperature: Int
    let high: Int
    let low: Int
    let condition: String
    let symbol: String

    static let mock = Forecast(temperature: 71, high: 74, low: 58,
                               condition: "Clear", symbol: "sun.max.fill")

    /// What the weather means for getting dressed, which is the only reason the
    /// app shows weather at all.
    var advice: String {
        switch temperature {
        case ..<45: "layer up — it's cold"
        case 45..<60: "bring something warm"
        case 60..<78: "good day for anything"
        default: "keep it light"
        }
    }
}
