import Foundation

struct CultureItemDraft: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let contentSourceID: String
    let sourceObjectID: String?
    let sourceURL: String
    let imageURL: String?
    let title: String
    let maker: String?
    let culture: String?
    let country: String?
    let region: String?
    let dateDisplay: String?
    let category: CultureCategory?
    let license: String?
    let rightsURL: String?
    let sourceName: String
    let hookDraft: String?
    let storyDraft: String?
    let whyItMattersDraft: String?
    let latitude: Double?
    let longitude: Double?
    let tags: [String]
    let curatorNotes: String?
    let status: CultureItemDraftStatus
    let candidateWeekKeys: [String]
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case contentSourceID = "content_source_id"
        case sourceObjectID = "source_object_id"
        case sourceURL = "source_url"
        case imageURL = "image_url"
        case title
        case maker
        case culture
        case country
        case region
        case dateDisplay = "date_display"
        case category
        case license
        case rightsURL = "rights_url"
        case sourceName = "source_name"
        case hookDraft = "hook_draft"
        case storyDraft = "story_draft"
        case whyItMattersDraft = "why_it_matters_draft"
        case latitude
        case longitude
        case tags
        case curatorNotes = "curator_notes"
        case status
        case candidateWeekKeys = "candidate_week_keys"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum CultureItemDraftStatus: String, Codable, Hashable, Sendable {
    case discovered
    case needsRightsReview = "needs_rights_review"
    case readyForCuration = "ready_for_curation"
    case curated
    case rejected
}

