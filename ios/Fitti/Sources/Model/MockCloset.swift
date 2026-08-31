import SwiftUI
import FittiDesign

/// Stand-in garments for the shell. Real ones arrive in stage 5 with actual
/// cutouts; until then a tile draws a coloured blob so the grid's rhythm,
/// spacing and motion can be judged for real.
struct MockGarment: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    /// The garment's dominant colour, which is what the tile draws.
    let hue: Double
    let timesWorn: Int
}

enum MockCloset {
    static let garments: [MockGarment] = [
        .init(name: "Wool overcoat",     category: "Outerwear", hue: 40,  timesWorn: 12),
        .init(name: "Oxford shirt",      category: "Top",       hue: 220, timesWorn: 31),
        .init(name: "Selvedge denim",    category: "Bottom",    hue: 250, timesWorn: 48),
        .init(name: "Fisherman knit",    category: "Top",       hue: 85,  timesWorn: 7),
        .init(name: "Suede loafers",     category: "Footwear",  hue: 30,  timesWorn: 22),
        .init(name: "Linen trousers",    category: "Bottom",    hue: 90,  timesWorn: 4),
        .init(name: "Striped tee",       category: "Top",       hue: 15,  timesWorn: 19),
        .init(name: "Field jacket",      category: "Outerwear", hue: 130, timesWorn: 9),
        .init(name: "Corduroy shirt",    category: "Top",       hue: 55,  timesWorn: 15),
        .init(name: "Runners",           category: "Footwear",  hue: 195, timesWorn: 63),
        .init(name: "Cashmere scarf",    category: "Accessory", hue: 350, timesWorn: 3),
        .init(name: "Chore coat",        category: "Outerwear", hue: 255, timesWorn: 11),
        .init(name: "Pleated chinos",    category: "Bottom",    hue: 60,  timesWorn: 26),
        .init(name: "Cricket jumper",    category: "Top",       hue: 160, timesWorn: 5),
        .init(name: "Leather belt",      category: "Accessory", hue: 25,  timesWorn: 40),
        .init(name: "Canvas sneakers",   category: "Footwear",  hue: 320, timesWorn: 17),
    ]

    /// Deliberately near the free ceiling so the limit meter reads as urgent in
    /// the shell rather than as an empty decoration.
    static let limit = 25
}

/// Catalogue stand-ins for Discover. `wornHue` is the on-model shot revealed by
/// press-and-hold; a real listing sometimes has no such photo, hence the optional.
struct MockListing: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let brand: String
    let price: String
    let hue: Double
    let wornHue: Double?
}

enum MockCatalog {
    static let listings: [MockListing] = [
        .init(name: "Cropped bomber",  brand: "Stussy",   price: "$180", hue: 40,  wornHue: 42),
        .init(name: "Wide-leg jean",   brand: "Carhartt", price: "$98",  hue: 245, wornHue: 248),
        .init(name: "Mohair cardigan", brand: "Our Legacy", price: "$320", hue: 350, wornHue: nil),
        .init(name: "Runner low",      brand: "Salomon",  price: "$140", hue: 195, wornHue: 200),
        .init(name: "Camp collar",     brand: "Uniqlo",   price: "$40",  hue: 85,  wornHue: 88),
        .init(name: "Barrel trouser",  brand: "Cos",      price: "$135", hue: 130, wornHue: nil),
        .init(name: "Suede blouson",   brand: "Lemaire",  price: "$890", hue: 30,  wornHue: 33),
        .init(name: "Rugby stripe",    brand: "Drake's",  price: "$165", hue: 15,  wornHue: 18),
    ]
}
