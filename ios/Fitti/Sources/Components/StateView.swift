import SwiftUI
import FittiDesign

/// Empty, loading, failed, offline.
///
/// Nothing in the app drew any of these four before — every screen assumed its
/// data had arrived. A UI that only ever renders its happy path is the most
/// reliable tell that it was generated rather than designed, because a designer
/// meets the empty case on day one and a generator never does.
///
/// One component rather than four: they are the same composition with a different
/// line. Fitti, something he says about it, and at most one way out. The copy is
/// his voice, so it is set in Gloria — and it never says "Error".
struct StateView: View {
    enum Kind {
        case empty, loading, failed, offline
    }

    let kind: Kind
    /// Fitti talking. One line, lowercase, no full stop — he is not a dialog box.
    let message: String
    /// Whatever the screen sets its text in: `onGround` on the app shell,
    /// `Fixed.ink` on Discover's paper.
    let foreground: Color
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.md) {
            // No spinner. The mascot is already a per-frame shader, so loading
            // winds him up rather than parking a second, duller animation next
            // to him competing for the same attention.
            Mascot(size: 96, isBusy: kind == .loading)

            Text(message)
                .font(.fittiHand)
                .foregroundStyle(foreground.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.fittiHeadline)
                        .foregroundStyle(foreground)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs)
                        .background(foreground.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.squash)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
