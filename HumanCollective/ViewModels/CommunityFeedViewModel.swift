import Foundation
import Observation

@MainActor
@Observable
final class CommunityFeedViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var artworks: [CommunityArtwork] = []

    @ObservationIgnored private let repository: any CommunityRepository
    @ObservationIgnored private var requestedCategory: CommunityCategory?

    init(repository: any CommunityRepository) {
        self.repository = repository
    }

    func loadIfNeeded(category: CommunityCategory?) async {
        guard state == .idle else { return }
        await refresh(category: category, showLoading: true)
    }

    func refresh(category: CommunityCategory?, showLoading: Bool = false) async {
        requestedCategory = category
        if showLoading {
            state = .loading
        }

        do {
            let fetched = try await repository.fetchFeed(category: category)
            guard !Task.isCancelled, requestedCategory == category else { return }
            artworks = fetched
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            if artworks.isEmpty {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
