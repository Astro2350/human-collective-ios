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

    init(
        id: String,
        title: String,
        maker: String?,
        culture: String?,
        country: String?,
        region: String?,
        dateDisplay: String,
        category: CultureCategory,
        imageURL: String,
        sourceName: String,
        sourceURL: String,
        license: String,
        hook: String,
        story: String,
        whyItMatters: String,
        latitude: Double?,
        longitude: Double?,
        weekKey: String
    ) {
        self.id = id
        self.title = title
        self.maker = maker
        self.culture = culture
        self.country = country
        self.region = region
        self.dateDisplay = dateDisplay
        self.category = category
        self.imageURL = imageURL
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.license = license
        self.hook = hook
        self.story = story
        self.whyItMatters = whyItMatters
        self.latitude = latitude
        self.longitude = longitude
        self.weekKey = weekKey
    }

    var placeDisplay: String {
        [culture, region, country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }

    var makerDisplay: String {
        creatorDisplay
    }

    var creatorDisplay: String {
        if let maker = maker?.trimmingCharacters(in: .whitespacesAndNewlines), !maker.isEmpty {
            return maker
        }

        if let culture = culture?.trimmingCharacters(in: .whitespacesAndNewlines), !culture.isEmpty {
            return "Unknown \(culture) creator"
        }

        return "Creator unknown"
    }

    var displayTitle: String {
        CultureItemTitleFormatter.displayTitle(from: title)
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            maker: try container.decodeIfPresent(String.self, forKey: .maker),
            culture: try container.decodeIfPresent(String.self, forKey: .culture),
            country: try container.decodeIfPresent(String.self, forKey: .country),
            region: try container.decodeIfPresent(String.self, forKey: .region),
            dateDisplay: try container.decode(String.self, forKey: .dateDisplay),
            category: try container.decode(CultureCategory.self, forKey: .category),
            imageURL: try container.decode(String.self, forKey: .imageURL),
            sourceName: try container.decode(String.self, forKey: .sourceName),
            sourceURL: try container.decode(String.self, forKey: .sourceURL),
            license: try container.decode(String.self, forKey: .license),
            hook: try container.decode(String.self, forKey: .hook),
            story: try container.decode(String.self, forKey: .story),
            whyItMatters: try container.decode(String.self, forKey: .whyItMatters),
            latitude: try container.decodeIfPresent(Double.self, forKey: .latitude),
            longitude: try container.decodeIfPresent(Double.self, forKey: .longitude),
            weekKey: try container.decode(String.self, forKey: .weekKey)
        )
    }
}

private enum CultureItemTitleFormatter {
    private static let idealLimit = 46

    static func displayTitle(from title: String) -> String {
        let normalizedTitle = normalized(title)

        if let override = curatedShortTitles[normalizedTitle] {
            return override
        }

        guard normalizedTitle.count > idealLimit else {
            return normalizedTitle
        }

        let deparenthesizedTitle = normalized(removingParentheticals(from: normalizedTitle))
        let candidates = [
            deparenthesizedTitle,
            prefix(before: ", from ", in: deparenthesizedTitle),
            prefix(before: ", Page from ", in: deparenthesizedTitle),
            prefix(before: ", plate ", in: deparenthesizedTitle),
            prefix(before: ", folio ", in: deparenthesizedTitle),
            prefix(before: ", no. ", in: deparenthesizedTitle),
            prefix(before: ", Possibly ", in: deparenthesizedTitle),
            prefix(before: ", with later ", in: deparenthesizedTitle),
            prefix(before: ", the ", in: deparenthesizedTitle),
            prefix(before: ", and ", in: deparenthesizedTitle),
            prefix(before: ", ", in: deparenthesizedTitle),
            prefix(before: ": ", in: deparenthesizedTitle)
        ]

        if let bestCandidate = candidates.compactMap({ $0 }).first(where: isUsefulTitle) {
            return bestCandidate
        }

        return wordBoundaryTrim(deparenthesizedTitle, limit: idealLimit)
    }

    private static let curatedShortTitles = [
        "Miniature Mountain with Shoulao (God of Longevity), the Eight Daoist Immortals, Scholars on Horseback, Monkey with Peach, and Deer with Mushroom of Immortality": "Miniature Mountain with Shoulao",
        "The Young Emperor Akbar Arrests the Insolent Shah Abu’l-Maali, Page from a Manuscript of the Akbarnama": "Akbar Arrests Shah Abu’l-Maali",
        "Enthroned Rama and Sita receive homage from their monkey and bear Allies, from the Yuddha Kanda (Book of the War) of a Ramayana (Rama’s Journey)": "Rama and Sita Receive Homage",
        "The Elephant of Maharana Jai Singh of Mewar (r. 1680–98) Catches a Horse by the Tail": "Elephant Catches a Horse by the Tail",
        "Two Landscapes with Dog, Putti, Rat, Cat, and Urn Border, folio 41 (recto), from Florilegium (A Book of Flower Studies)": "Two Landscapes with Animal Border",
        "The Same Man Throws a Bull in the Ring at Madrid, plate 16 from The Art of Bullfighting": "Man Throws a Bull in the Ring",
        "The Forceful Rendón Stabs a Bull with the Pique, from which Pass He Died in the Ring at Madrid, plate 28 from The Art of Bullfighting": "Rendón Stabs a Bull with the Pique",
        "Circassian Cavalry Awaiting their Commanding Officer at the Door of a Byzantine Monument; Memory of the Orient": "Circassian Cavalry at a Monument",
        "Jar, scales and bowl, no. 6 from the series \"The Rabbit's Boastful Exploits (Usagi tegarabanashi)\"": "The Rabbit's Boastful Exploits",
        "Tulips with Poppy, Carnation, Snail, Bug, and Frog Border, folio 3 (recto), from Florilegium (A Book of Flower Studies)": "Tulips with Snail and Frog Border"
    ]

    private static func normalized(_ title: String) -> String {
        title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removingParentheticals(from title: String) -> String {
        title.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func prefix(before marker: String, in title: String) -> String? {
        guard let range = title.range(of: marker, options: [.caseInsensitive]) else {
            return nil
        }

        return normalized(String(title[..<range.lowerBound]))
    }

    private static func isUsefulTitle(_ title: String) -> Bool {
        title.count >= 8 && title.count <= idealLimit
    }

    private static func wordBoundaryTrim(_ title: String, limit: Int) -> String {
        guard title.count > limit else { return title }

        let index = title.index(title.startIndex, offsetBy: limit)
        let prefix = String(title[..<index])

        if let lastSpace = prefix.lastIndex(where: { $0 == " " }) {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        }

        return prefix.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
