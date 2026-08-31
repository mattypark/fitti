import SwiftUI

/// A 4pt base. Screen gutters are 20.
public enum Space {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let gutter: CGFloat = 20
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64

    /// The closet grid gap. Deliberately tiny: the tiles nearly touch so the closet
    /// reads as one continuous surface rather than a set of separate cards.
    public static let grid: CGFloat = 2
}

public enum Radius {
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 12
    /// Garment tiles.
    public static let tile: CGFloat = 20
    /// Sheets.
    public static let sheet: CGFloat = 32
    public static let pill: CGFloat = 999
}
