import Foundation

protocol CommunityRepository {
    func fetchFeed(category: CultureCategory?) async throws -> [CommunityArtwork]
    func submit(_ draft: CommunitySubmissionDraft) async throws -> UUID
    func report(artworkID: UUID, reason: CommunityReportReason, details: String) async throws
}

enum CommunityRepositoryError: LocalizedError {
    case notConfigured
    case invalidResponse
    case requestFailed
    case rateLimited
    case submissionsUnavailable
    case artworkUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Community submissions are temporarily unavailable."
        case .invalidResponse, .requestFailed:
            "The request could not be completed. Please try again."
        case .rateLimited:
            "You’ve reached the submission limit for now. Please try again later."
        case .submissionsUnavailable:
            "Submissions are unavailable from this device."
        case .artworkUnavailable:
            "This artwork is no longer available."
        }
    }
}

enum CommunityRepositoryFactory {
    static func make() -> any CommunityRepository {
        guard let configuration = SupabaseConfiguration.fromBundle() else {
            return UnavailableCommunityRepository()
        }

        return SupabaseCommunityRepository(configuration: configuration)
    }
}

private struct UnavailableCommunityRepository: CommunityRepository {
    func fetchFeed(category: CultureCategory?) async throws -> [CommunityArtwork] {
        []
    }

    func submit(_ draft: CommunitySubmissionDraft) async throws -> UUID {
        throw CommunityRepositoryError.notConfigured
    }

    func report(artworkID: UUID, reason: CommunityReportReason, details: String) async throws {
        throw CommunityRepositoryError.notConfigured
    }
}
