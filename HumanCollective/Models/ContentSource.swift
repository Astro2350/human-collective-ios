import Foundation

struct ContentSource: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: ContentSourceKind
    let homepageURL: String
    let apiURL: String?
    let searchURL: String?
    let rightsSummary: String
    let preferredCreditLine: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case homepageURL = "homepage_url"
        case apiURL = "api_url"
        case searchURL = "search_url"
        case rightsSummary = "rights_summary"
        case preferredCreditLine = "preferred_credit_line"
        case notes
    }
}

enum ContentSourceKind: String, Codable, Hashable, Sendable {
    case museum
    case archive
    case library
    case commons
    case monument
    case other
}

