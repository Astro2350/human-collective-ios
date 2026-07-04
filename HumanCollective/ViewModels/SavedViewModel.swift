import Foundation
import Observation

@MainActor
@Observable
final class SavedViewModel {
    var state: LoadState<[CultureItem]> = .idle

    func load(from savedStore: SavedStore, repository: any CultureRepository) async {
        let savedItems = savedStore.savedItems
        guard !savedItems.isEmpty else {
            state = .empty
            return
        }

        do {
            let refreshedItems = try await repository.fetchItems(ids: Set(savedItems.map(\.id)))
            let refreshedByID = Dictionary(uniqueKeysWithValues: refreshedItems.map { ($0.id, $0) })
            let mergedItems = savedItems.map { refreshedByID[$0.id] ?? $0 }

            savedStore.replaceSavedItems(mergedItems)
            state = .loaded(mergedItems)
        } catch is CancellationError {
            return
        } catch {
            state = .loaded(savedItems)
        }
    }
}
