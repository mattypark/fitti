import Testing
import Foundation
@testable import FittiEngine

/// Mirrors web/tests/outfits.test.ts. Two implementations of this scoring exist —
/// the phone must work offline and the server writes the copy — so both sides
/// assert the same behaviour and the constants stay honest.
struct OutfitEngineTests {

    private func piece(
        _ id: String,
        covers: Set<Slot> = [.top],
        hue: Double = 85,
        chroma: Double = 0.1,
        pattern: Pattern = .solid,
        formality: Int = 3,
        warmth: Int = 3,
        waterproof: Bool? = nil,
        lastWorn: Date? = nil
    ) -> Piece {
        Piece(id: id, name: id, covers: covers, hue: hue, chroma: chroma,
              pattern: pattern, formality: formality, warmth: warmth,
              isWaterproof: waterproof, lastWorn: lastWorn)
    }

    @Test("Neutrals go with anything")
    func neutralsMatchEverything() {
        let black = piece("black", hue: 0, chroma: 0.01)
        let loud = piece("loud", hue: 300, chroma: 0.2)
        #expect(OutfitEngine.harmony(black, loud) == 1)
    }

    @Test("Analogous and complementary read as deliberate; the middle does not")
    func hueBands() {
        let base = piece("base", hue: 30, chroma: 0.15)
        #expect(OutfitEngine.harmony(base, piece("near", hue: 55, chroma: 0.15)) == 1)
        #expect(OutfitEngine.harmony(base, piece("opposite", hue: 205, chroma: 0.15)) >= 0.85)
        #expect(OutfitEngine.harmony(base, piece("awkward", hue: 120, chroma: 0.15)) < 0.5)
    }

    @Test("Hue distance wraps around the circle")
    func hueWraps() {
        let a = piece("a", hue: 350, chroma: 0.15)
        let b = piece("b", hue: 20, chroma: 0.15)
        #expect(OutfitEngine.harmony(a, b) == 1, "350 and 20 are 30 apart, not 330")
    }

    @Test("One pattern is a focal point, two is a fight")
    func patterns() {
        let solid = piece("s")
        let striped = piece("st", pattern: .striped)
        let floral = piece("f", pattern: .floral)
        #expect(OutfitEngine.patternScore([solid, striped]) > OutfitEngine.patternScore([solid, solid]))
        #expect(OutfitEngine.patternScore([striped, floral]) < 0.6)
    }

    @Test("Mixed dress codes are penalised")
    func formality() {
        #expect(OutfitEngine.formalityScore([piece("a", formality: 3), piece("b", formality: 3)]) == 1)
        #expect(OutfitEngine.formalityScore([piece("a", formality: 1), piece("b", formality: 5)]) < 0.3)
    }

    @Test("Never-worn pieces score highest — the anti-rut term")
    func novelty() {
        let never = OutfitEngine.noveltyScore([piece("never")])
        let yesterday = OutfitEngine.noveltyScore([
            piece("recent", lastWorn: Date().addingTimeInterval(-86_400))
        ])
        #expect(never == 1)
        #expect(yesterday < 0.5, "something worn yesterday should not come straight back")
    }

    @Test("Warmth is a band — a parka is as wrong in July as a vest is in January")
    func warmthBand() {
        let parka = piece("parka", warmth: 5)
        let vest = piece("vest", warmth: 1)

        let hot = OutfitEngine.weatherFilter([parka, vest], Conditions(temperatureF: 88))
        #expect(hot.map(\.id) == ["vest"])

        let cold = OutfitEngine.weatherFilter([parka, vest], Conditions(temperatureF: 30))
        #expect(cold.map(\.id) == ["parka"])
    }

    @Test("Rain rules out shoes known not to survive it")
    func rain() {
        let suede = piece("suede", covers: [.footwear], waterproof: false)
        let boots = piece("boots", covers: [.footwear], waterproof: true)
        let wet = OutfitEngine.weatherFilter([suede, boots], Conditions(temperatureF: 60, isRaining: true))
        #expect(wet.map(\.id) == ["boots"])
    }

    @Test("A dress makes an outfit with shoes alone")
    func dressCountsAsTwoSlots() {
        let outfits = OutfitEngine.build(
            from: [piece("dress", covers: [.top, .bottom]), piece("shoes", covers: [.footwear])],
            conditions: Conditions(temperatureF: 65)
        )
        #expect(outfits.count == 1)
        #expect(Set(outfits[0].pieces.map(\.id)) == ["dress", "shoes"])
    }

    @Test("A small closet still yields three options, none identical")
    func smallCloset() {
        let pieces = [
            piece("t1", covers: [.top]),
            piece("t2", covers: [.top], hue: 200),
            piece("b1", covers: [.bottom]),
            piece("b2", covers: [.bottom], hue: 210),
            piece("s1", covers: [.footwear]),
            piece("s2", covers: [.footwear], hue: 220),
        ]
        let outfits = OutfitEngine.build(from: pieces, conditions: Conditions(temperatureF: 65), limit: 3)
        #expect(outfits.count == 3)

        let keys = outfits.map { $0.pieces.map(\.id).sorted().joined(separator: "+") }
        #expect(Set(keys).count == 3, "duplicate outfit returned")

        // The top two must differ substantially, not by a single shoe swap.
        let first = Set(outfits[0].pieces.map(\.id))
        let second = Set(outfits[1].pieces.map(\.id))
        #expect(first.intersection(second).count <= 1)
    }

    @Test("An empty closet yields nothing rather than crashing")
    func emptyCloset() {
        #expect(OutfitEngine.build(from: [], conditions: Conditions(temperatureF: 65)).isEmpty)
    }

    @Test("Scoring explains itself")
    func reasons() {
        let outfit = OutfitEngine.score(
            [piece("a", hue: 30, chroma: 0.15), piece("b", hue: 45, chroma: 0.15)],
            Conditions(temperatureF: 65)
        )
        #expect(outfit.reasons.contains("the colours sit together"))
    }
}
