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
        DailyArtifactTitleFormatter.displayTitle(from: title)
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

    func matchesSearch(_ query: String) -> Bool {
        CultureSearchMatcher.matches(
            query,
            values: [
                title,
                maker,
                culture,
                country,
                region,
                dateDisplay,
                category.title,
                category.displayName,
                category.rawValue,
                hook,
                story,
                whyItMatters,
                sourceName,
            ]
        )
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

enum CultureSearchMatcher {
    static func matches(_ query: String, values: [String?]) -> Bool {
        let terms = normalized(query)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !terms.isEmpty else { return false }

        let searchableText = normalized(
            values
                .compactMap { $0 }
                .joined(separator: " ")
        )

        return terms.allSatisfy(searchableText.contains)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
    }
}

enum CultureContentQuality {
    static func appStoreReadyPack(_ pack: CulturePack) -> CulturePack? {
        let readyItems = pack.items.filter(isAppStoreReady)
        guard !readyItems.isEmpty else { return nil }

        return CulturePack(
            id: pack.id,
            weekKey: pack.weekKey,
            title: pack.title,
            subtitle: pack.subtitle,
            startDate: pack.startDate,
            endDate: pack.endDate,
            items: readyItems
        )
    }

    static func isAppStoreReady(_ item: CultureItem) -> Bool {
        hasUsefulText(item.title, minimumLength: 2) &&
            hasValidURL(item.imageURL) &&
            hasValidURL(item.sourceURL) &&
            hasUsefulText(item.hook, minimumLength: 12) &&
            hasUsefulText(item.story, minimumLength: 40) &&
            hasUsefulText(item.whyItMatters, minimumLength: 20)
    }

    private static func hasValidURL(_ value: String) -> Bool {
        let trimmedValue = normalized(value)
        guard !trimmedValue.isEmpty,
              let url = URL(string: trimmedValue),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }

        return !containsTemporaryContent(trimmedValue)
    }

    private static func hasUsefulText(_ value: String, minimumLength: Int) -> Bool {
        let trimmedValue = normalized(value)
        guard trimmedValue.count >= minimumLength else { return false }
        return !containsTemporaryContent(trimmedValue)
    }

    private static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsTemporaryContent(_ value: String) -> Bool {
        let loweredValue = value.lowercased()
        let temporaryMarkers = [
            "placeholder",
            "lorem ipsum",
            "coming soon",
            "todo",
            "needs copy",
            "needs image",
            "needs rights",
            "needs review",
            "draft copy",
            "sample content"
        ]

        return temporaryMarkers.contains { loweredValue.contains($0) }
    }
}
