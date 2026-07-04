import Foundation
import Observation

@MainActor
@Observable
final class CultureDetailViewModel {
    let item: CultureItem
    var isSaved: Bool

    @ObservationIgnored private let savedStore: SavedStore

    init(item: CultureItem, savedStore: SavedStore) {
        self.item = item
        self.savedStore = savedStore
        self.isSaved = savedStore.isSaved(item)
    }

    func toggleSaved() {
        savedStore.toggle(item)
        isSaved = savedStore.isSaved(item)
    }
}
