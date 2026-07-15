import Foundation

struct CommunityArtwork: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let contributorID: UUID
    let title: String
    let creatorName: String
    let significance: String
    let category: CultureCategory
    let imageURL: String
    let publishedAt: Date

    var savedCultureItem: CultureItem {
        CultureItem(
            id: "collective-\(id.uuidString.lowercased())",
            title: title,
            maker: creatorName,
            culture: nil,
            country: nil,
            region: nil,
            dateDisplay: publishedAt.formatted(.dateTime.year()),
            category: category,
            imageURL: imageURL,
            sourceName: "The Human Collective",
            sourceURL: "",
            license: "Shared by the creator for display in the Collective",
            hook: "",
            story: "",
            whyItMatters: significance,
            latitude: nil,
            longitude: nil,
            weekKey: "collective"
        )
    }
}

struct CommunitySubmissionDraft: Sendable {
    let title: String
    let creatorName: String
    let significance: String
    let category: CultureCategory
    let jpegData: Data
    let rightsConfirmed: Bool
}

enum CommunitySubmissionReviewStatus: String, Codable, Hashable, Sendable {
    case pending
    case approved
    case rejected
    case removed

    var title: String {
        switch self {
        case .pending: "Under review"
        case .approved: "Published"
        case .rejected: "Not selected"
        case .removed: "Removed"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: "clock"
        case .approved: "checkmark.circle.fill"
        case .rejected: "minus.circle"
        case .removed: "xmark.circle"
        }
    }
}

struct CommunitySubmissionStatus: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let status: CommunitySubmissionReviewStatus
    let reviewedAt: Date?
}

enum CommunitySubmissionValidator {
    static func message(
        jpegData: Data?,
        title: String,
        creatorName: String,
        significance: String,
        rightsConfirmed: Bool
    ) -> String? {
        guard jpegData != nil else {
            return "Choose a clear, high-resolution photo."
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.count >= 2 else {
            return "Add the artwork title."
        }
        guard trimmedTitle.count <= 120 else {
            return "Keep the artwork title to 120 characters or fewer."
        }

        let trimmedName = creatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count >= 2 else {
            return "Add the creator’s name. Use Unknown if it isn’t known."
        }
        guard trimmedName.count <= 60 else {
            return "Keep the name to 60 characters or fewer."
        }

        let trimmedSignificance = significance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSignificance.count >= 40 else {
            return "Add a little more about why it matters (40 characters minimum)."
        }
        guard trimmedSignificance.count <= 600 else {
            return "Keep the significance to 600 characters or fewer."
        }
        guard rightsConfirmed else {
            return "Confirm that you created the work and permit us to display it."
        }

        return nil
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
