import SwiftUI
import FittiDesign

/// The header every sheet gets: a way out, on the left, always in the same place.
///
/// Previously each sheet invented its own — "Done" here, "Not now" there, and the
/// consent sheet had no exit at all while also disabling swipe-to-dismiss, which
/// trapped anyone who opened it. A single control in a fixed position is both the
/// fix and the thing that stops the app feeling assembled from parts.
struct SheetChrome<Trailing: View>: View {
    let title: String?
    let palette: Palette
    var onClose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Button {
                Haptics.shared.tap()
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.onGround)
                    .frame(width: 40, height: 40)
                    .background(palette.groundLift, in: Circle())
            }
            .buttonStyle(.squash)
            .accessibilityLabel("Back")

            Spacer()

            if let title {
                Text(title)
                    .font(.fittiHeadline)
                    .foregroundStyle(palette.onGround)
            }

            Spacer()

            trailing()
                // Keeps the title optically centred by balancing the back button's
                // width, rather than letting a short trailing item pull it left.
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
    }
}

extension SheetChrome where Trailing == EmptyView {
    init(title: String? = nil, palette: Palette, onClose: @escaping () -> Void) {
        self.init(title: title, palette: palette, onClose: onClose) { EmptyView() }
    }
}
