import Foundation
import Observation

@MainActor
@Observable
final class SavedStore {
    private(set) var savedItems: [CultureItem]
    private(set) var revision: Int = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "humanCulture.savedItems"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CultureItem].self, from: data) {
            self.savedItems = decoded
        } else {
            self.savedItems = []
        }
    }

    var savedIDs: Set<String> {
        Set(savedItems.map(\.id))
    }

    func isSaved(_ item: CultureItem) -> Bool {
        savedIDs.contains(item.id)
    }

    func save(_ item: CultureItem) {
        guard !isSaved(item) else { return }
        savedItems.insert(item, at: 0)
        persist()
    }

    func unsave(_ item: CultureItem) {
        savedItems.removeAll { $0.id == item.id }
        persist()
    }

    func toggle(_ item: CultureItem) {
        if isSaved(item) {
            unsave(item)
        } else {
            save(item)
        }
    }

    func replaceSavedItems(_ items: [CultureItem]) {
        guard savedItems != items else { return }
        savedItems = items
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(savedItems) {
            defaults.set(data, forKey: key)
        }
        revision += 1
    }
}
