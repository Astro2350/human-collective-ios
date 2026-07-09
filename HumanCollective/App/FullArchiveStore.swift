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

    struct SupportOption: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let displayPrice: String
    }

    static let legacyProductID = "com.sam.HumanCollective.fullArchive"
    static let accessProductID = "com.sam.HumanCollective.fullArchive.access"
    static let standardProductID = "com.sam.HumanCollective.fullArchive.standard"
    static let patronProductID = "com.sam.HumanCollective.fullArchive.patron"

    static let productID = standardProductID
    private static let debugAccessOverrideKey = "HCFullArchiveDebugAccessOverride"
    private static let productIDs = [
        accessProductID,
        standardProductID,
        patronProductID,
        legacyProductID
    ]

    private(set) var products: [Product] = []
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var hasFullArchiveAccess = false
    private(set) var activePurchaseProductID: String?

    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var priceText: String {
        products.first?.displayPrice ?? ""
    }

    var purchaseButtonTitle: String {
        if hasFullArchiveAccess {
            return "Unlocked"
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

    var supportOptions: [SupportOption] {
        products
            .filter { Self.supportDetails[$0.id] != nil }
            .sorted { Self.sortIndex(for: $0.id) < Self.sortIndex(for: $1.id) }
            .map { product in
                let details = Self.supportDetails[product.id] ?? Self.fallbackSupportDetails
                return SupportOption(
                    id: product.id,
                    title: details.title,
                    subtitle: details.subtitle,
                    displayPrice: product.displayPrice
                )
            }
    }

    var canOfferFullArchivePurchase: Bool {
        if hasFullArchiveAccess {
            return true
        }

        if case .unavailable = purchaseState {
            return false
        }

        return true
    }

    var statusMessage: String? {
        switch purchaseState {
        case .failed(let message):
            return message
        case .unavailable:
            return nil
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
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted { Self.sortIndex(for: $0.id) < Self.sortIndex(for: $1.id) }
            purchaseState = products.isEmpty ? .unavailable : .idle
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

        let productID = products.first?.id ?? Self.productID
        await purchase(productID: productID)
    }

    func purchase(productID: String) async {
        if applyDebugAccessOverrideIfNeeded() {
            return
        }

        guard !hasFullArchiveAccess else {
            purchaseState = .unlocked
            return
        }

        var product = products.first { $0.id == productID }
        if product == nil {
            await loadProducts()
            product = products.first { $0.id == productID }
        }

        guard let product else {
            purchaseState = .unavailable
            return
        }

        activePurchaseProductID = productID
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
                activePurchaseProductID = nil
                await transaction.finish()
            case .userCancelled:
                purchaseState = .idle
                activePurchaseProductID = nil
            case .pending:
                purchaseState = .failed("Purchase is pending approval.")
                activePurchaseProductID = nil
            @unknown default:
                purchaseState = .failed("Purchase couldn't be completed.")
                activePurchaseProductID = nil
            }
        } catch {
            purchaseState = .failed("Purchase couldn't be completed. Please try again.")
            activePurchaseProductID = nil
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
            activePurchaseProductID = nil
            purchaseState = hasFullArchiveAccess ? .unlocked : .failed("No Full Archive purchase was found.")
        } catch {
            activePurchaseProductID = nil
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
            if Self.productIDs.contains(transaction.productID) {
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
        guard Self.productIDs.contains(transaction.productID) else { return }

        hasFullArchiveAccess = true
        purchaseState = .unlocked
        activePurchaseProductID = nil
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

    private static let fallbackSupportDetails = (
        title: "Full Archive",
        subtitle: "Unlock every past piece."
    )

    private static let supportDetails: [String: (title: String, subtitle: String)] = [
        accessProductID: (
            title: "Access",
            subtitle: "Unlocks everything."
        ),
        standardProductID: (
            title: "Standard",
            subtitle: "More museum and app support."
        ),
        patronProductID: (
            title: "Patron",
            subtitle: "Most museum and app support."
        ),
        legacyProductID: (
            title: "Full Archive",
            subtitle: "Unlock every past piece."
        )
    ]

    private static func sortIndex(for productID: String) -> Int {
        productIDs.firstIndex(of: productID) ?? productIDs.count
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
