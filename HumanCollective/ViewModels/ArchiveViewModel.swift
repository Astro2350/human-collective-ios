import Foundation
import Observation

@MainActor
@Observable
final class ArchiveViewModel {
    var state: LoadState<[CulturePack]> = .idle

    @ObservationIgnored private let repository: any CultureRepository

    init(repository: any CultureRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading

        do {
            let packs = try await repository.fetchArchivePacks()
            state = packs.isEmpty ? .empty : .loaded(packs)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

