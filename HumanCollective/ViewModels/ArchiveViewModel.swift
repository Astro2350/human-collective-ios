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
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return "Couldn't load the archive. Check your connection and try again."
            case .timedOut:
                return "The archive is taking a little longer than usual. Try again in a moment."
            default:
                break
            }
        }

        return "Couldn't load the archive. Please try again."
    }
}
