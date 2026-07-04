import Foundation

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String

    static func fromBundle() -> SupabaseConfiguration? {
        let bundleURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        let bundleKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        let environment = ProcessInfo.processInfo.environment

        let rawURL = clean(value: environment["SUPABASE_URL"] ?? bundleURL)
        let rawKey = clean(value: environment["SUPABASE_ANON_KEY"] ?? bundleKey)

        guard let rawURL, let rawKey, let url = URL(string: rawURL) else {
            return nil
        }

        return SupabaseConfiguration(url: url, anonKey: rawKey)
    }

    private static func clean(value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }
}

struct SupabaseCultureRepository: CultureRepository {
    private let configuration: SupabaseConfiguration
    private let decoder: JSONDecoder

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
    }

    func fetchCurrentPack() async throws -> CulturePack {
        let packs: [SupabasePackDTO] = try await request(
            table: "culture_packs",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "start_date.desc"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        guard let pack = packs.first else {
            throw CultureRepositoryError.emptyResponse
        }

        return try await hydrate(pack: pack)
    }

    func fetchArchivePacks() async throws -> [CulturePack] {
        let today = Self.dateFormatter.string(from: Date())
        let packs: [SupabasePackDTO] = try await request(
            table: "culture_packs",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "end_date", value: "lt.\(today)"),
                URLQueryItem(name: "order", value: "start_date.desc")
            ]
        )

        var hydratedPacks: [CulturePack] = []
        for pack in packs {
            hydratedPacks.append(try await hydrate(pack: pack))
        }
        return hydratedPacks
    }

    func fetchPack(weekKey: String) async throws -> CulturePack? {
        let packs: [SupabasePackDTO] = try await request(
            table: "culture_packs",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "week_key", value: "eq.\(weekKey)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        guard let pack = packs.first else { return nil }
        return try await hydrate(pack: pack)
    }

    func fetchItems(ids: Set<String>) async throws -> [CultureItem] {
        guard !ids.isEmpty else { return [] }

        let items: [SupabaseCultureItemDTO] = try await request(
            table: "culture_items",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "in.(\(ids.sorted().joined(separator: ",")))")
            ]
        )

        return items.map { $0.model }
    }

    private func hydrate(pack: SupabasePackDTO) async throws -> CulturePack {
        let rows: [SupabasePackItemDTO] = try await request(
            table: "culture_pack_items",
            queryItems: [
                URLQueryItem(name: "select", value: "position,item:culture_items(*)"),
                URLQueryItem(name: "pack_id", value: "eq.\(pack.id)"),
                URLQueryItem(name: "order", value: "position.asc")
            ]
        )

        return CulturePack(
            id: pack.id,
            weekKey: pack.weekKey,
            title: pack.title,
            subtitle: pack.subtitle ?? "",
            startDate: Self.dateFormatter.date(from: pack.startDate ?? "") ?? Date(),
            endDate: Self.dateFormatter.date(from: pack.endDate ?? "") ?? Date(),
            items: rows.sorted { $0.position < $1.position }.map(\.item.model)
        )
    }

    private func request<T: Decodable>(
        table: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        guard var components = URLComponents(
            url: configuration.url.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw CultureRepositoryError.invalidURL
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw CultureRepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw CultureRepositoryError.requestFailed(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct SupabasePackDTO: Decodable {
    let id: String
    let weekKey: String
    let title: String
    let subtitle: String?
    let startDate: String?
    let endDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case weekKey = "week_key"
        case title
        case subtitle
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

private struct SupabasePackItemDTO: Decodable {
    let position: Int
    let item: SupabaseCultureItemDTO
}

private struct SupabaseCultureItemDTO: Decodable {
    let id: String
    let title: String
    let maker: String?
    let culture: String?
    let country: String?
    let region: String?
    let dateDisplay: String?
    let category: String?
    let imageURL: String?
    let sourceName: String?
    let sourceURL: String?
    let license: String?
    let hook: String?
    let story: String?
    let whyItMatters: String?
    let latitude: Double?
    let longitude: Double?
    let weekKey: String?

    var model: CultureItem {
        CultureItem(
            id: id,
            title: title,
            maker: maker,
            culture: culture,
            country: country,
            region: region,
            dateDisplay: dateDisplay ?? "Date unknown",
            category: CultureCategory(rawValue: category ?? "") ?? .other,
            imageURL: imageURL ?? "",
            sourceName: sourceName ?? "Source unknown",
            sourceURL: sourceURL ?? "",
            license: license ?? "License unknown",
            hook: hook ?? "",
            story: story ?? "",
            whyItMatters: whyItMatters ?? "",
            latitude: latitude,
            longitude: longitude,
            weekKey: weekKey ?? ""
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
}
