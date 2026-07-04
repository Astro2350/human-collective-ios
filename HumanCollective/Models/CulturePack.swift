import Foundation

struct CulturePack: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let weekKey: String
    let title: String
    let subtitle: String
    let startDate: Date
    let endDate: Date
    let items: [CultureItem]

    var featuredItem: CultureItem? {
        items.first
    }

    enum CodingKeys: String, CodingKey {
        case id
        case weekKey = "week_key"
        case title
        case subtitle
        case startDate = "start_date"
        case endDate = "end_date"
        case items
    }
}

