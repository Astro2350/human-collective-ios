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
            state = .failed(Self.message(for: error))
        }
    }

    func retry() async {
        await load()
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return "Couldn't load this week's pack. Check your connection and try again."
            case .timedOut:
                return "This week's pack is taking a little longer than usual. Try again in a moment."
            default:
                break
            }
        }

        if let repositoryError = error as? CultureRepositoryError {
            switch repositoryError {
            case .emptyResponse:
                return "Couldn't find a published pack for this week."
            case .invalidURL, .notConfigured:
                return "The culture archive connection is not configured."
            case .requestFailed:
                return "Couldn't load this week's pack. Please try again."
            }
        }

        return "Couldn't load this week's pack. Check your connection and try again."
    }
}
