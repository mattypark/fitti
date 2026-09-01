import SwiftUI

/// SF Pro does all the work. Bagel Fat One says the name. Gloria Hallelujah is the
/// mascot's own voice, and nothing else.
///
/// Both Google faces ship bundled under the OFL. Nothing is fetched at runtime.
///
/// The restraint is the point. Alta and Cosmos each ship one licensed text family and
/// no display face at all; Alta's 100px hero is weight 500, not black. A display face
/// carrying section headers across five screens is what reads as generated.
public enum Typeface {
    /// PostScript names, NOT filenames. SwiftUI's `Font.custom` matches on the
    /// PostScript name and falls back to the system font **silently** when it
    /// doesn't — no warning, no crash, just the wrong typeface. Gloria's is
    /// "GloriaHallelujah" even though the file is GloriaHallelujah-Regular.ttf,
    /// which is exactly the kind of mismatch that ships unnoticed.
    public static let bagel = "BagelFatOne-Regular"
    public static let gloria = "GloriaHallelujah"
}

public extension Font {
    /// The logotype. One call site — the wordmark on the welcome screen. If this
    /// appears anywhere else, the restraint above has been lost.
    static let fittiDisplay = Font.custom(Typeface.bagel, size: 34, relativeTo: .largeTitle)

    /// Section headers — "YOUR CLOSET". SF Pro at medium, not Bagel: the weight
    /// carries the hierarchy so the face doesn't have to shout it.
    static let fittiTitle = Font.system(.title, design: .default, weight: .medium)

    static let fittiHeadline = Font.system(.headline, design: .default, weight: .medium)
    static let fittiBody = Font.system(.body, design: .default, weight: .regular)
    static let fittiCallout = Font.system(.subheadline, design: .default, weight: .regular)
    /// Secondary metadata that sits under a headline — a place, a reason, a date.
    static let fittiFootnote = Font.system(.footnote, design: .default, weight: .regular)
    static let fittiLabel = Font.system(.caption, design: .default, weight: .medium)
    /// Fine print, tab labels, the week strip. The smallest text the app is allowed
    /// to set; below this nobody reads it and it becomes texture.
    static let fittiFine = Font.system(.caption2, design: .default, weight: .regular)

    /// Fitti talking. The tagline, empty states, the note on an outfit — never a
    /// label on a control, and never ordinary interface chrome.
    static let fittiHand = Font.custom(Typeface.gloria, size: 16, relativeTo: .callout)
}

public extension View {
    /// The wordmark. Negative tracking because Bagel's default sidebearings are drawn
    /// for a body face; at 34pt they read as gaps.
    func fittiDisplayStyle() -> some View {
        font(.fittiDisplay).tracking(-0.5)
    }

    /// Section headers. The tracking is slight and load-bearing — SF Pro at 28 is
    /// drawn for reading, and a header is scanned.
    func fittiTitleStyle() -> some View {
        font(.fittiTitle).tracking(-0.2)
    }

    /// Tracked-out uppercase metadata. The tracking is what makes 12pt read as a label
    /// rather than as small body text.
    func fittiLabelStyle() -> some View {
        font(.fittiLabel)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
