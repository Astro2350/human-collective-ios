import Foundation
import UIKit

struct WidgetArtifact: Sendable {
    let title: String
    let imageURL: URL
    let category: String
    let detail: String

    var initials: String {
        title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

enum WidgetArtifactLoader {
    static func loadToday() async throws -> WidgetArtifact {
        let configuration = try Configuration.fromBundle()
        let today = dateFormatter.string(from: Date())

        let packs: [PackDTO] = try await request(
            configuration: configuration,
            table: "culture_packs",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "start_date", value: "lte.\(today)"),
                URLQueryItem(name: "end_date", value: "gte.\(today)"),
                URLQueryItem(name: "order", value: "start_date.desc"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let pack = packs.first else { throw LoaderError.noArtifact }

        let rows: [PackItemDTO] = try await request(
            configuration: configuration,
            table: "culture_pack_items",
            queryItems: [
                URLQueryItem(name: "select", value: "position,item:culture_items(*)"),
                URLQueryItem(name: "pack_id", value: "eq.\(pack.id)"),
                URLQueryItem(name: "order", value: "position.asc")
            ]
        )

        let candidates = rows
            .filter(\.item.isAppStoreReady)
            .sorted { $0.position < $1.position }
            .prefix(7)
        guard !candidates.isEmpty else { throw LoaderError.noArtifact }

        let calendar = cultureCalendar
        let packStart = dateFormatter.date(from: pack.startDate) ?? Date()
        guard let index = DailyArtifactDaySelector.index(
            startDate: packStart,
            on: Date(),
            itemCount: candidates.count,
            calendar: calendar
        ) else { throw LoaderError.noArtifact }
        let item = Array(candidates)[index].item

        guard let imageURL = URL(string: item.imageURL), imageURL.scheme?.hasPrefix("http") == true else {
            throw LoaderError.invalidImageURL
        }

        let detail = [item.culture, item.country, item.dateDisplay]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            .prefix(2)
            .joined(separator: " · ")

        return WidgetArtifact(
            title: DailyArtifactTitleFormatter.displayTitle(from: item.title),
            imageURL: imageURL,
            category: item.category.capitalized,
            detail: detail
        )
    }

    static func loadImageData(from url: URL, maximumDimension: CGFloat) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("HumanCollectiveWidget/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw LoaderError.requestFailed
        }
        guard let thumbnailData = ArtifactImageProcessor.jpegThumbnailData(
            from: data,
            maximumDimension: maximumDimension
        ) else {
            throw LoaderError.invalidImageData
        }
        return thumbnailData
    }

    private static func request<T: Decodable>(
        configuration: Configuration,
        table: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        guard var components = URLComponents(
            url: configuration.url.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw LoaderError.invalidConfiguration
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw LoaderError.invalidConfiguration }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw LoaderError.requestFailed
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static var cultureCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct Configuration {
    let url: URL
    let anonKey: String

    static func fromBundle() throws -> Configuration {
        let rawURL = clean(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
        let rawKey = clean(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)
        guard let rawURL, let rawKey, let url = URL(string: rawURL) else {
            throw LoaderError.invalidConfiguration
        }
        return Configuration(url: url, anonKey: rawKey)
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }
}

private struct PackDTO: Decodable {
    let id: String
    let startDate: String

    enum CodingKeys: String, CodingKey {
        case id
        case startDate = "start_date"
    }
}

private struct PackItemDTO: Decodable {
    let position: Int
    let item: ItemDTO
}

private struct ItemDTO: Decodable {
    let title: String
    let imageURL: String
    let category: String
    let culture: String?
    let country: String?
    let dateDisplay: String?
    let sourceURL: String?
    let hook: String?
    let story: String?
    let whyItMatters: String?

    var isAppStoreReady: Bool {
        hasUsefulText(title, minimumLength: 2) &&
            hasValidURL(imageURL) &&
            hasValidURL(sourceURL) &&
            hasUsefulText(hook, minimumLength: 12) &&
            hasUsefulText(story, minimumLength: 40) &&
            hasUsefulText(whyItMatters, minimumLength: 20)
    }

    enum CodingKeys: String, CodingKey {
        case title
        case imageURL = "image_url"
        case category
        case culture
        case country
        case dateDisplay = "date_display"
        case sourceURL = "source_url"
        case hook
        case story
        case whyItMatters = "why_it_matters"
    }

    private func hasValidURL(_ value: String?) -> Bool {
        guard let normalized = normalized(value),
              let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }
        return !containsTemporaryContent(normalized)
    }

    private func hasUsefulText(_ value: String?, minimumLength: Int) -> Bool {
        guard let normalized = normalized(value), normalized.count >= minimumLength else { return false }
        return !containsTemporaryContent(normalized)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func containsTemporaryContent(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return [
            "placeholder", "lorem ipsum", "coming soon", "todo", "needs copy",
            "needs image", "needs rights", "needs review", "draft copy", "sample content"
        ].contains { lowered.contains($0) }
    }
}

private enum LoaderError: LocalizedError {
    case invalidConfiguration
    case noArtifact
    case invalidImageURL
    case requestFailed
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Human Collective is not configured."
        case .noArtifact:
            "Today's artifact is not available yet."
        case .invalidImageURL:
            "Today's artifact image is invalid."
        case .requestFailed:
            "The daily artifact could not be loaded."
        case .invalidImageData:
            "Today's artifact image could not be prepared for the widget."
        }
    }
}
