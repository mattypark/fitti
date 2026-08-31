import SwiftUI
import StoreKit
import FittiDesign

/// Shown when the closet hits the free ceiling.
///
/// It arrives at the moment of friction rather than at launch, so by the time
/// anyone reads it they have already put 25 real pieces in and know what the app
/// is for. Nothing here is hidden behind the paywall except capacity.
struct PaywallView: View {
    let entitlements: Entitlements
    let palette: Palette

    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        ZStack {
            palette.ground.ignoresSafeArea()
            BlobDots(screen: "paywall", count: 3).ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                Mascot(size: 110)

                VStack(spacing: Space.xs) {
                    Text("CLOSET FULL")
                        .font(.fittiTitle)
                        .foregroundStyle(palette.onGround)

                    Text("that's 25 pieces —\nnice closet")
                        .font(.fittiHand)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.onGroundSoft)
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    perk("As many pieces as you own")
                    perk("Everything else stays exactly as it is")
                    perk("Cancel whenever")
                }
                .padding(.vertical, Space.md)

                Spacer()

                if let error {
                    Text(error)
                        .font(.fittiCallout)
                        .foregroundStyle(palette.accent)
                        .multilineTextAlignment(.center)
                }

                buyButton

                Button("Restore purchase") {
                    Task { await entitlements.restore() }
                }
                .font(.fittiCallout)
                .foregroundStyle(palette.onGroundSoft)

                Button("Not now") { dismiss() }
                    .font(.fittiCallout)
                    .foregroundStyle(palette.onGroundSoft)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .task { await entitlements.refresh() }
        .onChange(of: entitlements.isPlus) { _, isPlus in
            if isPlus { dismiss() }
        }
    }

    private func perk(_ text: String) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.accent)
            Text(text)
                .font(.fittiBody)
                .foregroundStyle(palette.onGround)
        }
    }

    @ViewBuilder
    private var buyButton: some View {
        if let product = entitlements.product {
            Button {
                Task {
                    do { try await entitlements.purchase() }
                    catch { self.error = "That didn't go through. No charge was made." }
                }
            } label: {
                Group {
                    if entitlements.isPurchasing {
                        ProgressView().tint(Fixed.ink)
                    } else {
                        Text("\(product.displayPrice) a month")
                            .font(.fittiHeadline)
                            .foregroundStyle(Fixed.ink)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Fixed.yellow, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }
            .buttonStyle(.squash)
            .disabled(entitlements.isPurchasing)
        } else if entitlements.loadFailed {
            // Never show a dead button. If the App Store did not answer, say so.
            Text("Can't reach the App Store right now.")
                .font(.fittiCallout)
                .foregroundStyle(palette.onGroundSoft)
                .frame(height: 54)
        } else {
            ProgressView()
                .frame(height: 54)
        }
    }
}
