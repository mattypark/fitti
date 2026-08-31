import Foundation

/// Which part of an outfit a garment fills. A dress covers two.
public enum Slot: String, Sendable, CaseIterable, Codable {
    case top, bottom, outerwear, footwear, accessory
}

public enum Pattern: String, Sendable, Codable {
    case solid, striped, checked, floral, graphic, other
}

public struct Piece: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let covers: Set<Slot>
    /// OKLCH hue angle of the dominant colour.
    public let hue: Double
    /// OKLCH chroma. Near zero is a neutral, which goes with anything.
    public let chroma: Double
    public let pattern: Pattern
    /// 1 loungewear ... 5 black tie.
    public let formality: Int
    /// 1 vest ... 5 parka.
    public let warmth: Int
    public let isWaterproof: Bool?
    public let lastWorn: Date?

    public init(id: String, name: String, covers: Set<Slot>, hue: Double, chroma: Double,
                pattern: Pattern = .solid, formality: Int = 3, warmth: Int = 3,
                isWaterproof: Bool? = nil, lastWorn: Date? = nil) {
        self.id = id
        self.name = name
        self.covers = covers
        self.hue = hue
        self.chroma = chroma
        self.pattern = pattern
        self.formality = formality
        self.warmth = warmth
        self.isWaterproof = isWaterproof
        self.lastWorn = lastWorn
    }
}

public struct Conditions: Sendable {
    public let temperatureF: Int
    public let isRaining: Bool
    /// Where it is going. An outfit is judged against the occasion, not in a vacuum.
    public let occasionFormality: Int?

    public init(temperatureF: Int, isRaining: Bool = false, occasionFormality: Int? = nil) {
        self.temperatureF = temperatureF
        self.isRaining = isRaining
        self.occasionFormality = occasionFormality
    }
}

public struct Outfit: Sendable, Identifiable {
    public let id = UUID()
    public let pieces: [Piece]
    public let score: Double
    /// Why it scored what it did. Shown to the user and asserted in tests.
    public let reasons: [String]
}
