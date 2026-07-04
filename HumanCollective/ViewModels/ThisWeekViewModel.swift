import Foundation
import Observation

@MainActor
@Observable
final class ThisWeekViewModel {
    var state: LoadState<CulturePack> = .idle

    @ObservationIgnored private let repository: any CultureRepository

    init(repository: any CultureRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading

        do {
            let pack = try await repository.fetchCurrentPack()
            state = pack.items.isEmpty ? .empty : .loaded(pack)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        await load()
    }
}

