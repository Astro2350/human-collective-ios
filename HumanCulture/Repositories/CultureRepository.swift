import Foundation

protocol CultureRepository {
    func fetchCurrentPack() async throws -> CulturePack
    func fetchArchivePacks() async throws -> [CulturePack]
    func fetchPack(weekKey: String) async throws -> CulturePack?
    func fetchItems(ids: Set<String>) async throws -> [CultureItem]
}

enum CultureRepositoryError: LocalizedError {
    case notConfigured
    case invalidURL
    case emptyResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase is not configured."
        case .invalidURL:
            "The Supabase URL is invalid."
        case .emptyResponse:
            "No culture pack was returned."
        case .requestFailed(let status):
            "Request failed with status \(status)."
        }
    }
}

enum CultureRepositoryFactory {
    static func make() -> any CultureRepository {
        guard let configuration = SupabaseConfiguration.fromBundle() else {
            return MockCultureRepository()
        }

        return SupabaseCultureRepository(configuration: configuration)
    }
}

