import Foundation

struct CommunityArtwork: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let contributorID: UUID
    let creatorName: String
    let significance: String
    let category: CommunityCategory
    let imageURL: String
    let publishedAt: Date
}

struct CommunitySubmissionDraft: Sendable {
    let creatorName: String
    let significance: String
    let category: CommunityCategory
    let jpegData: Data
    let rightsConfirmed: Bool
}

enum CommunityCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case art
    case craft
    case photography
    case design
    case writing
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .art: "Art"
        case .craft: "Craft"
        case .photography: "Photography"
        case .design: "Design"
        case .writing: "Writing"
        case .other: "Other"
        }
    }
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
