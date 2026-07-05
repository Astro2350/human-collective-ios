import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class FullArchiveStore {
    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case restoring
        case unlocked
        case unavailable
        case failed(String)
    }

    static let productID = "com.sam.HumanCollective.fullArchive"
    private static let debugAccessOverrideKey = "HCFullArchiveDebugAccessOverride"

    private(set) var product: Product?
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var hasFullArchiveAccess = false

    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var priceText: String {
        product?.displayPrice ?? ""
    }

    var purchaseButtonTitle: String {
        if hasFullArchiveAccess {
            return "Unlocked"
        }

        if let product {
            return product.displayPrice.isEmpty ? "Unlock Full Archive" : "Unlock for \(product.displayPrice)"
        }

        switch purchaseState {
        case .loading:
            return "Loading"
        case .purchasing:
            return "Purchasing"
        case .restoring:
            return "Restoring"
        default:
            return "Unlock Full Archive"
        }
    }

    var statusMessage: String? {
        switch purchaseState {
        case .failed(let message):
            return message
        case .unavailable:
            return "Full Archive is not available yet. Check that the in-app purchase is active in App Store Connect."
        default:
            return nil
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func start() {
        applyDebugAccessOverrideFromLaunchArguments()

        guard transactionUpdatesTask == nil else { return }

        if applyDebugAccessOverrideIfNeeded() {
            return
        }

        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: update)
            }
        }

        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    func loadProducts() async {
        if applyDebugAccessOverrideIfNeeded() {
            return
        }

        guard !hasFullArchiveAccess else {
            purchaseState = .unlocked
            return
        }

        purchaseState = .loading

        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            purchaseState = product == nil ? .unavailable : .idle
        } catch {
            purchaseState = .failed("Couldn't load the Full Archive purchase. Try again in a moment.")
        }
    }

    func purchase() async {
        if applyDebugAccessOverrideIfNeeded() {
            return
        }

        guard !hasFullArchiveAccess else {
            purchaseState = .unlocked
            return
        }

        if product == nil {
            await loadProducts()
        }

        guard let product else {
            purchaseState = .unavailable
            return
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    purchaseState = .failed("Couldn't verify the purchase. Please try again.")
                    return
                }

                hasFullArchiveAccess = true
                purchaseState = .unlocked
                await transaction.finish()
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .failed("Purchase is pending approval.")
            @unknown default:
                purchaseState = .failed("Purchase couldn't be completed.")
            }
        } catch {
            purchaseState = .failed("Purchase couldn't be completed. Please try again.")
        }
    }

    func restorePurchases() async {
        if applyDebugAccessOverrideIfNeeded() {
            return
        }

        purchaseState = .restoring

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = hasFullArchiveAccess ? .unlocked : .failed("No Full Archive purchase was found.")
        } catch {
            purchaseState = .failed("Couldn't restore purchases. Please try again.")
        }
    }

    func refreshEntitlements() async {
        if applyDebugAccessOverrideIfNeeded() {
            return
        }

        var isUnlocked = false

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: entitlement) else { continue }
            if transaction.productID == Self.productID {
                isUnlocked = true
                break
            }
        }

        hasFullArchiveAccess = isUnlocked
        if isUnlocked {
            purchaseState = .unlocked
        } else if case .unlocked = purchaseState {
            purchaseState = .idle
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = verifiedTransaction(from: transactionResult) else { return }
        guard transaction.productID == Self.productID else { return }

        hasFullArchiveAccess = true
        purchaseState = .unlocked
        await transaction.finish()
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }

    @discardableResult
    private func applyDebugAccessOverrideIfNeeded() -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Self.debugAccessOverrideKey) {
            hasFullArchiveAccess = true
            purchaseState = .unlocked
            return true
        }
        #endif

        return false
    }

    private func applyDebugAccessOverrideFromLaunchArguments() {
        #if DEBUG
        let arguments = CommandLine.arguments

        if arguments.contains("-HCUnlockFullArchive") {
            UserDefaults.standard.set(true, forKey: Self.debugAccessOverrideKey)
        } else if arguments.contains("-HCLockFullArchive") {
            UserDefaults.standard.removeObject(forKey: Self.debugAccessOverrideKey)
            hasFullArchiveAccess = false
            purchaseState = .idle
        }
        #endif
    }
}
