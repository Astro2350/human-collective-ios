import Foundation

struct CultureItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
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
    let weekKey: String

    var placeDisplay: String {
        [culture, region, country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }

    var makerDisplay: String {
        guard let maker, !maker.isEmpty else { return "Maker unknown" }
        return maker
    }

    var cardMetadataDisplay: String {
        let origins: [String?] = [culture, country, region]
        let origin = origins.compactMap { $0 }.first { !$0.isEmpty }

        return ([origin, dateDisplay] as [String?])
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " - ")
    }

    enum CodingKeys: String, CodingKey {
        case id
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
        case weekKey = "week_key"
    }
}
