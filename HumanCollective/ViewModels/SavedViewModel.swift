import Foundation
import Observation

@MainActor
@Observable
final class SavedViewModel {
    var state: LoadState<[CultureItem]> = .idle

    func load(from savedStore: SavedStore, repository: any CultureRepository) async {
        let savedItems = savedStore.savedItems
        display(savedItems)
        guard !savedItems.isEmpty else { return }

        do {
            let refreshedItems = try await repository.fetchItems(ids: Set(savedItems.map(\.id)))
            let refreshedByID = Dictionary(uniqueKeysWithValues: refreshedItems.map { ($0.id, $0) })
            let currentSavedItems = savedStore.savedItems
            let mergedItems = currentSavedItems.map { refreshedByID[$0.id] ?? $0 }

            savedStore.replaceSavedItems(mergedItems)
            display(mergedItems)
        } catch is CancellationError {
            return
        } catch {
            display(savedStore.savedItems)
        }
    }

    func display(_ items: [CultureItem]) {
        state = items.isEmpty ? .empty : .loaded(items)
    }
}
