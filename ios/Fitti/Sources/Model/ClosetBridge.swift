import Foundation
import FittiEngine

/// Turns what's in the closet into what the outfit engine expects.
///
/// A deliberate seam. The engine knows nothing about capture queues, tiles or
/// SwiftUI — it takes pieces and conditions and returns outfits — which is why it
/// can be tested in a second from the command line instead of only in a simulator.
enum ClosetBridge {

    static func pieces(from garments: [MockGarment]) -> [Piece] {
        garments.map { garment in
            Piece(
                id: garment.id.uuidString,
                name: garment.name,
                covers: covers(for: garment.category),
                hue: garment.hue,
                // Real chroma arrives with colour extraction in the ingest
                // pipeline. Until then everything is treated as coloured rather
                // than neutral, which is the conservative choice: it applies the
                // harmony rules rather than skipping them.
                chroma: 0.11,
                formality: 3,
                warmth: warmth(for: garment.category),
                lastWorn: garment.timesWorn > 0
                    ? Date().addingTimeInterval(-Double(garment.timesWorn) * 43_200)
                    : nil
            )
        }
    }

    private static func covers(for category: String) -> Set<Slot> {
        switch category.lowercased() {
        case "top": [.top]
        case "bottom": [.bottom]
        case "dress": [.top, .bottom]
        case "outerwear": [.outerwear]
        case "footwear": [.footwear]
        default: [.accessory]
        }
    }

    private static func warmth(for category: String) -> Int {
        switch category.lowercased() {
        case "outerwear": 4
        case "top": 3
        default: 2
        }
    }
}
