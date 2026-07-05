import Foundation

struct AdminSeedData: Codable, Hashable, Sendable {
    let schemaVersion: String
    let generatedAt: String
    let notes: String?
    let contentSources: [ContentSource]
    let draftItems: [CultureItemDraft]
    let curatedItems: [AdminSeedCultureItem]
    let weeklyPacks: [AdminSeedCulturePack]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case notes
        case contentSources = "content_sources"
        case draftItems = "draft_items"
        case curatedItems = "curated_items"
        case weeklyPacks = "weekly_packs"
    }
}

struct AdminSeedCultureItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let contentSourceID: String
    let sourceObjectID: String?
    let title: String
    let maker: String?
    let culture: String?
    let country: String?
    let region: String?
    let dateDisplay: String
    let category: CultureCategory
    let imageURL: String
    let sourceName: String
    let sourceURL: String
    let license: String
    let hook: String
    let story: String
    let whyItMatters: String
    let latitude: Double?
    let longitude: Double?
    let primaryWeekKey: String?
    let tags: [String]
    let curatorNote: String?

    func cultureItem(weekKey: String? = nil) -> CultureItem {
        CultureItem(
            id: id,
            title: title,
            maker: maker,
            culture: culture,
            country: country,
            region: region,
            dateDisplay: dateDisplay,
            category: category,
            imageURL: imageURL,
            sourceName: sourceName,
            sourceURL: sourceURL,
            license: license,
            hook: hook,
            story: story,
            whyItMatters: whyItMatters,
            latitude: latitude,
            longitude: longitude,
            weekKey: weekKey ?? primaryWeekKey ?? ""
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contentSourceID = "content_source_id"
        case sourceObjectID = "source_object_id"
        case title
        case maker
        case culture
        case country
        case region
        case dateDisplay = "date_display"
        case category
        case imageURL = "image_url"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case license
        case hook
        case story
        case whyItMatters = "why_it_matters"
        case latitude
        case longitude
        case primaryWeekKey = "primary_week_key"
        case tags
        case curatorNote = "curator_note"
    }
}

struct AdminSeedCulturePack: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let weekKey: String
    let title: String
    let subtitle: String
    let startDate: String
    let endDate: String
    let itemIDs: [String]
    let curatorNote: String?

    enum CodingKeys: String, CodingKey {
        case id
        case weekKey = "week_key"
        case title
        case subtitle
        case startDate = "start_date"
        case endDate = "end_date"
        case itemIDs = "item_ids"
        case curatorNote = "curator_note"
    }
}
