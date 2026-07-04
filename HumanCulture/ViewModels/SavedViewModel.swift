import Foundation
import Observation

@MainActor
@Observable
final class SavedViewModel {
    var state: LoadState<[CultureItem]> = .idle

    func load(from savedStore: SavedStore) {
        let items = savedStore.savedItems
        state = items.isEmpty ? .empty : .loaded(items)
    }
}

