import Foundation
import Observation

@MainActor
@Observable
final class BlockedCommunityStore {
    private(set) var contributorIDs: Set<UUID>
    private(set) var revision = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "humanCulture.blockedCommunityContributors"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: key) ?? []
        self.contributorIDs = Set(stored.compactMap(UUID.init(uuidString:)))
    }

    func contains(_ contributorID: UUID) -> Bool {
        contributorIDs.contains(contributorID)
    }

    func block(_ contributorID: UUID) {
        guard contributorIDs.insert(contributorID).inserted else { return }
        persist()
    }

    private func persist() {
        defaults.set(contributorIDs.map(\.uuidString).sorted(), forKey: key)
        revision += 1
    }
}
