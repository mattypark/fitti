import Foundation
import StoreKit
import Observation

/// What the user is allowed to do.
///
/// The client copy is a convenience for drawing the UI. It is deliberately NOT
/// the authority: the 25-piece ceiling is also a trigger in Postgres
/// (`enforce_garment_limit`), so a modified client that lies about its tier still
/// cannot write a 26th row. Never let the phone be the only thing standing
/// between a user and the paid tier.
@Observable
@MainActor
final class Entitlements {
    static let plusProductID = "com.matthewpark.fitti.plus.monthly"
    static let freeLimit = 25

    private(set) var isPlus = false
    private(set) var product: Product?
    private(set) var isPurchasing = false
    private(set) var loadFailed = false

    private var updatesTask: Task<Void, Never>?

    init() {
        // Must start before any purchase can complete. Transactions can arrive
        // while the app is closed — from a family member's approval, a retried
        // payment, or a restore on another device — and are delivered here on
        // next launch. Miss this and a user who paid stays on the free tier.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func refresh() async {
        await loadProduct()
        await refreshEntitlement()
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.plusProductID]).first
            loadFailed = product == nil
        } catch {
            loadFailed = true
        }
    }

    /// The source of truth on device: what Apple currently says is active.
    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.plusProductID, transaction.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
    }

    func purchase() async throws {
        guard let product else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        switch try await product.purchase() {
        case .success(let verification):
            await handle(verification)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        // `.unverified` means the signature did not check out. Ignore it rather
        // than granting access — this is the case a cracked client produces.
        guard case .verified(let transaction) = result else { return }
        await refreshEntitlement()
        await transaction.finish()
    }

    /// Whether one more garment is allowed. Mirrors the database trigger exactly.
    func canAdd(currentCount: Int) -> Bool {
        isPlus || currentCount < Self.freeLimit
    }

    var limit: Int { isPlus ? .max : Self.freeLimit }
}
