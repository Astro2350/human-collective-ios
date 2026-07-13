import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SupportStore {
    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case succeeded
        case pending
        case unavailable
        case failed(String)
    }

    struct SupportOption: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let displayPrice: String
    }

    static let smallProductID = "com.sam.HumanCollective.support.small"
    static let standardProductID = "com.sam.HumanCollective.support.standard"
    static let generousProductID = "com.sam.HumanCollective.support.generous"

    private static let productIDs = [smallProductID, standardProductID, generousProductID]
    private static let supportDetails: [String: (title: String, subtitle: String)] = [
        smallProductID: (
            title: "Small Support",
            subtitle: "A small optional tip."
        ),
        standardProductID: (
            title: "Generous Support",
            subtitle: "A generous optional tip."
        ),
        generousProductID: (
            title: "Patron Support",
            subtitle: "A larger optional tip."
        )
    ]

    private(set) var products: [Product] = []
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var activePurchaseProductID: String?

    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var supportOptions: [SupportOption] {
        products
            .filter { Self.supportDetails[$0.id] != nil && $0.type == .consumable }
            .sorted { Self.sortIndex(for: $0.id) < Self.sortIndex(for: $1.id) }
            .map { product in
                let details = Self.supportDetails[product.id]!
                return SupportOption(
                    id: product.id,
                    title: details.title,
                    subtitle: details.subtitle,
                    displayPrice: product.displayPrice
                )
            }
    }

    var statusMessage: String? {
        switch purchaseState {
        case .succeeded:
            "Thank you for supporting The Human Collective."
        case .pending:
            "Your support is pending approval."
        case .failed(let message):
            message
        default:
            nil
        }
    }

    var isBusy: Bool {
        switch purchaseState {
        case .loading, .purchasing:
            true
        case .idle, .succeeded, .pending, .unavailable, .failed:
            false
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func start() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: update)
            }
        }

        Task { await loadProducts() }
    }

    func loadProducts() async {
        guard !isBusy else { return }
        purchaseState = .loading

        do {
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted { Self.sortIndex(for: $0.id) < Self.sortIndex(for: $1.id) }
            purchaseState = supportOptions.isEmpty ? .unavailable : .idle
        } catch {
            purchaseState = .failed("Support options couldn't be loaded. Please try again later.")
        }
    }

    func purchase(productID: String) async {
        guard !isBusy else { return }

        var product = products.first { $0.id == productID && $0.type == .consumable }
        if product == nil {
            await loadProducts()
            product = products.first { $0.id == productID && $0.type == .consumable }
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
                guard let transaction = verifiedTransaction(from: verification),
                      Self.productIDs.contains(transaction.productID) else {
                    purchaseState = .failed("The purchase couldn't be verified. Please try again.")
                    activePurchaseProductID = nil
                    return
                }

                purchaseState = .succeeded
                activePurchaseProductID = nil
                await transaction.finish()
            case .userCancelled:
                purchaseState = .idle
                activePurchaseProductID = nil
            case .pending:
                purchaseState = .pending
                activePurchaseProductID = nil
            @unknown default:
                purchaseState = .failed("The purchase couldn't be completed.")
                activePurchaseProductID = nil
            }
        } catch {
            purchaseState = .failed("The purchase couldn't be completed. Please try again.")
            activePurchaseProductID = nil
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = verifiedTransaction(from: transactionResult),
              Self.productIDs.contains(transaction.productID) else { return }

        purchaseState = .succeeded
        activePurchaseProductID = nil
        await transaction.finish()
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            transaction
        case .unverified:
            nil
        }
    }

    private static func sortIndex(for productID: String) -> Int {
        productIDs.firstIndex(of: productID) ?? productIDs.count
    }
}
