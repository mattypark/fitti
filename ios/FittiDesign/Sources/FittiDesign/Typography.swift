import SwiftUI

/// SF Pro does the work. Bagel Fat One is the loud voice. Gloria Hallelujah is
/// handwriting — a voice, never a label on a control.
///
/// Both Google faces ship bundled under the OFL. Nothing is fetched at runtime.
public enum Typeface {
    public static let bagel = "BagelFatOne-Regular"
    public static let gloria = "GloriaHallelujah-Regular"
}

public extension Font {
    /// The logotype and the biggest moments.
    static let fittiDisplay = Font.custom(Typeface.bagel, size: 34)
    /// Section headers — "YOUR CLOSET".
    static let fittiTitle = Font.custom(Typeface.bagel, size: 22)
    /// Big counts. The limit meter's number.
    static let fittiNumeral = Font.custom(Typeface.bagel, size: 44)

    static let fittiHeadline = Font.system(size: 17, weight: .semibold)
    static let fittiBody = Font.system(size: 17, weight: .regular)
    static let fittiCallout = Font.system(size: 15, weight: .regular)
    static let fittiLabel = Font.system(size: 12, weight: .medium)

    /// Your note on an outfit. Empty states. The mascot talking.
    static let fittiHand = Font.custom(Typeface.gloria, size: 16)
}

public extension View {
    /// Tracked-out uppercase metadata. The tracking is what makes 12pt read as a label
    /// rather than as small body text.
    func fittiLabelStyle() -> some View {
        font(.fittiLabel)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
