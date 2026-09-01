import SwiftUI
import FittiDesign

/// Consent before any photo reaches an outside AI service.
///
/// App Store guideline 5.1.2(i), added November 2025: you must clearly disclose
/// where personal data will be shared with third parties, **including with
/// third-party AI**, and obtain explicit permission before doing so. Naming the
/// provider is the part most apps miss — "we use AI" does not satisfy it.
///
/// Declining is a real choice here, not a dead end. Cutouts run on the phone
/// anyway, so a user who says no still gets a working closet; they just fill in
/// names and colours themselves.
struct AIConsentView: View {
    let palette: Palette
    var onDecision: (Bool) -> Void

    var body: some View {
        ZStack {
            palette.ground.ignoresSafeArea()
            BlobDots(screen: "consent", count: 3).ignoresSafeArea()

            VStack(spacing: Space.lg) {
                SheetChrome(palette: palette) { onDecision(false) }

                Spacer()
                Mascot(size: 100)

                Text("BEFORE WE START")
                    .font(.fittiTitle)
                    .foregroundStyle(palette.onGround)

                VStack(alignment: .leading, spacing: Space.md) {
                    row("Your phone does the cutouts",
                        "Separating a garment from its background happens on this device. Those photos never leave it.")
                    row("Naming things needs help",
                        "To label a piece — its type, colour, material — Fitti sends that one photo to Google Gemini. Nothing else goes with it: no name, no email, no location.")
                    row("You can say no",
                        "Fitti still works. You'll just name and categorise pieces yourself, and nothing is ever sent anywhere.")
                }
                .padding(.horizontal, Space.xs)

                Spacer()

                Button {
                    onDecision(true)
                } label: {
                    Text("Let Fitti label my clothes")
                        .font(.fittiHeadline)
                        .foregroundStyle(Fixed.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Fixed.yellow,
                                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                }
                .buttonStyle(.squash)

                Button("I'll label them myself") { onDecision(false) }
                    .font(.fittiCallout)
                    .foregroundStyle(palette.onGroundSoft)

                Text("You can change this any time in You → Privacy.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onGroundSoft)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.xl)
        }
        // Swipe-to-dismiss counts as declining, rather than being blocked. A
        // sheet you cannot leave is worse than one whose default answer is no.
        .presentationDragIndicator(.visible)
    }

    private func row(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.fittiHeadline)
                .foregroundStyle(palette.onGround)
            Text(body)
                .font(.fittiCallout)
                .foregroundStyle(palette.onGroundSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Where the answer lives.
///
/// Three states, not two: nobody has been asked yet, they said yes, they said no.
/// Collapsing "not asked" into "no" would silently skip the prompt forever.
enum AIConsent {
    private static let key = "fitti.ai.consent"

    static var hasDecided: Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }

    static var isGranted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
