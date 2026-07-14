import Foundation

struct CommunityArtwork: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let contributorID: UUID
    let creatorName: String
    let significance: String
    let imageURL: String
    let publishedAt: Date
}

struct CommunitySubmissionDraft: Sendable {
    let creatorName: String
    let significance: String
    let jpegData: Data
    let rightsConfirmed: Bool
}

enum CommunityReportReason: String, CaseIterable, Identifiable, Sendable {
    case inappropriate
    case stolen
    case harassment
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inappropriate: "Inappropriate content"
        case .stolen: "Possibly stolen artwork"
        case .harassment: "Harassment or hateful content"
        case .spam: "Spam or misleading"
        case .other: "Something else"
        }
    }
}
