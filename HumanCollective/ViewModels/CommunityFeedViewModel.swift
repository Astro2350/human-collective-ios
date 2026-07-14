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

    init(repository: any CommunityRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await refresh(showLoading: true)
    }

    func refresh(showLoading: Bool = false) async {
        if showLoading {
            state = .loading
        }

        do {
            let fetched = try await repository.fetchFeed()
            guard !Task.isCancelled else { return }
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
