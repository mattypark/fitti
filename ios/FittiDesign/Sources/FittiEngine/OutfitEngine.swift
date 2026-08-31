import Foundation

/// Builds outfits from what someone actually owns.
///
/// Deliberately deterministic and on-device. A language model writes the one-line
/// "why" on top of this, but it never picks the clothes: it does not know what is
/// clean, what was worn yesterday, or what the weather is, and it will happily
/// suggest a garment the user does not own.
///
/// Mirrors `web/src/lib/outfits/engine.ts`. Two implementations exist because the
/// phone must work offline and the server writes the copy; the scoring constants
/// are the contract between them, and both sides have tests asserting the same
/// behaviour.
public enum OutfitEngine {

    /// Neutrals go with everything, so hue distance means nothing below this.
    static let neutralChroma = 0.04

    public static func weatherFilter(_ pieces: [Piece], _ conditions: Conditions) -> [Piece] {
        pieces.filter { piece in
            if conditions.isRaining,
               piece.covers.contains(.footwear),
               piece.isWaterproof == false {
                return false
            }
            // Warmth is a band, not a floor. Rejecting only "too cold" would put
            // people in parkas in July.
            if conditions.temperatureF >= 75 && piece.warmth >= 4 { return false }
            if conditions.temperatureF <= 45 && piece.warmth <= 1 { return false }
            return true
        }
    }

    /// Colour harmony off the hue circle.
    ///
    /// Analogous (within 40°) and complementary (near 180°) both read as
    /// deliberate. The 60–120° band is what looks accidental, and it is the only
    /// thing actually penalised.
    public static func harmony(_ a: Piece, _ b: Piece) -> Double {
        if a.chroma < neutralChroma || b.chroma < neutralChroma { return 1 }

        let raw = abs(a.hue - b.hue).truncatingRemainder(dividingBy: 360)
        let distance = raw > 180 ? 360 - raw : raw

        switch distance {
        case ..<40: return 1
        case 150...: return 0.9
        case 60...120: return 0.35
        default: return 0.65
        }
    }

    /// Two busy patterns fight. One against solids is a focal point.
    public static func patternScore(_ pieces: [Piece]) -> Double {
        let busy = pieces.filter { $0.pattern != .solid }.count
        switch busy {
        case 0: return 0.85
        case 1: return 1
        default: return max(0, 0.5 - Double(busy - 2) * 0.25)
        }
    }

    /// An outfit should be one register throughout. Mixing 2 and 5 reads as a mistake.
    public static func formalityScore(_ pieces: [Piece], target: Int? = nil) -> Double {
        let levels = pieces.map(\.formality)
        guard let low = levels.min(), let high = levels.max() else { return 0 }

        let spread = high - low
        var score = spread <= 1 ? 1 : max(0, 1 - Double(spread - 1) * 0.4)

        if let target {
            let mean = Double(levels.reduce(0, +)) / Double(levels.count)
            score *= max(0, 1 - abs(mean - Double(target)) * 0.3)
        }
        return score
    }

    /// Surfaces pieces the user owns and never wears.
    ///
    /// The single most valuable term here. The loudest complaint about every
    /// competitor is that it restyles the same handful of items and ignores the
    /// rest of the wardrobe — that complaint is exactly this term missing.
    public static func noveltyScore(_ pieces: [Piece], now: Date = Date()) -> Double {
        guard !pieces.isEmpty else { return 0 }
        let scores = pieces.map { piece -> Double in
            guard let lastWorn = piece.lastWorn else { return 1 }  // never worn
            let days = now.timeIntervalSince(lastWorn) / 86_400
            return min(1, log10(max(days, 1) + 1) / 1.5)
        }
        return scores.reduce(0, +) / Double(scores.count)
    }

    public static func score(_ pieces: [Piece], _ conditions: Conditions, now: Date = Date()) -> Outfit {
        var reasons: [String] = []

        var colour = 1.0
        for i in pieces.indices {
            for j in pieces.indices where j > i {
                colour = min(colour, harmony(pieces[i], pieces[j]))
            }
        }

        let pattern = patternScore(pieces)
        let formality = formalityScore(pieces, target: conditions.occasionFormality)
        let novelty = noveltyScore(pieces, now: now)

        if colour >= 0.9 { reasons.append("the colours sit together") }
        if pattern < 0.6 { reasons.append("two patterns competing") }
        if formality < 0.6 { reasons.append("mixed dress codes") }
        if novelty > 0.8 { reasons.append("brings back something you never wear") }

        let total = colour * 0.35 + pattern * 0.2 + formality * 0.25 + novelty * 0.2
        return Outfit(pieces: pieces, score: total, reasons: reasons)
    }

    private static func combinations(_ pieces: [Piece]) -> [[Piece]] {
        let shoes = pieces.filter { $0.covers.contains(.footwear) }
        // A dress covers top and bottom at once, so it forms an outfit with shoes
        // alone. Requiring one piece per slot would silently exclude every dress.
        let dresses = pieces.filter { $0.covers.contains(.top) && $0.covers.contains(.bottom) }
        let tops = pieces.filter { $0.covers.contains(.top) && !$0.covers.contains(.bottom) }
        let bottoms = pieces.filter { $0.covers.contains(.bottom) && !$0.covers.contains(.top) }

        var results: [[Piece]] = []
        for dress in dresses {
            for shoe in shoes { results.append([dress, shoe]) }
        }
        for top in tops {
            for bottom in bottoms {
                for shoe in shoes { results.append([top, bottom, shoe]) }
            }
        }
        return results
    }

    public static func build(
        from pieces: [Piece],
        conditions: Conditions,
        limit: Int = 3,
        now: Date = Date()
    ) -> [Outfit] {
        let eligible = weatherFilter(pieces, conditions)
        let scored = combinations(eligible)
            .map { score($0, conditions, now: now) }
            .sorted { $0.score > $1.score }

        // Three variations on one shirt is the failure to avoid. But a small
        // closet cannot produce three wholly separate outfits, and returning one
        // suggestion because someone is just starting out is worse than returning
        // three that share a piece. So: distinct first, then top up.
        var chosen: [Outfit] = []

        func overlapsTooMuch(_ candidate: Outfit) -> Bool {
            chosen.contains { picked in
                let ids = Set(picked.pieces.map(\.id))
                let shared = candidate.pieces.filter { ids.contains($0.id) }.count
                return Double(shared) > Double(candidate.pieces.count) / 2
            }
        }

        for outfit in scored where chosen.count < limit {
            if overlapsTooMuch(outfit) { continue }
            chosen.append(outfit)
        }

        for outfit in scored where chosen.count < limit {
            let ids = outfit.pieces.map(\.id)
            let duplicate = chosen.contains { $0.pieces.map(\.id) == ids }
            if !duplicate { chosen.append(outfit) }
        }

        return chosen
    }
}
