import Foundation
import Security

struct SupabaseCommunityRepository: CommunityRepository {
    private let configuration: SupabaseConfiguration
    private let decoder = JSONDecoder()

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
    }

    func fetchFeed(category: CultureCategory?) async throws -> [CommunityArtwork] {
        guard var components = URLComponents(
            url: configuration.url.appendingPathComponent("rest/v1/community_artworks"),
            resolvingAgainstBaseURL: false
        ) else {
            throw CommunityRepositoryError.invalidResponse
        }

        var queryItems = [
            URLQueryItem(
                name: "select",
                value: "id,contributor_id,title,creator_name,significance,category,image_path,published_at"
            ),
            URLQueryItem(name: "is_active", value: "eq.true"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "100")
        ]
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: "eq.\(category.rawValue)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw CommunityRepositoryError.invalidResponse
        }

        var request = authorizedRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await responseData(for: request)
        let rows = try decoder.decode([CommunityArtworkDTO].self, from: data)
        return rows.compactMap(makeArtwork)
    }

    func submit(_ draft: CommunitySubmissionDraft) async throws -> UUID {
        let endpoint = configuration.url.appendingPathComponent("functions/v1/community-submit")
        let boundary = "HumanCollective-\(UUID().uuidString)"
        var request = authorizedRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let installationID = CommunityInstallationIdentity.current().uuidString.lowercased()
        let body = MultipartFormData(boundary: boundary)
            .adding(name: "title", value: draft.title)
            .adding(name: "creator_name", value: draft.creatorName)
            .adding(name: "significance", value: draft.significance)
            .adding(name: "category", value: draft.category.rawValue)
            .adding(name: "installation_id", value: installationID)
            .adding(name: "rights_confirmed", value: draft.rightsConfirmed ? "true" : "false")
            .adding(
                name: "image",
                filename: "creation.jpg",
                contentType: "image/jpeg",
                data: draft.jpegData
            )
            .encoded()

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try validate(response: response, data: data)

        guard let receipt = try? decoder.decode(SubmissionReceiptDTO.self, from: data) else {
            throw CommunityRepositoryError.invalidResponse
        }

        return receipt.id
    }

    func fetchSubmissionStatuses(ids: [UUID]) async throws -> [CommunitySubmissionStatus] {
        let uniqueIDs = Array(Set(ids)).prefix(20)
        guard !uniqueIDs.isEmpty else { return [] }

        let endpoint = configuration.url.appendingPathComponent("functions/v1/community-status")
        var request = authorizedRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SubmissionStatusRequestDTO(
                installationID: CommunityInstallationIdentity.current(),
                ids: Array(uniqueIDs)
            )
        )

        let data = try await responseData(for: request)
        let response = try decoder.decode(SubmissionStatusResponseDTO.self, from: data)
        return response.submissions.map { row in
            CommunitySubmissionStatus(
                id: row.id,
                status: row.status,
                reviewedAt: row.reviewedAt.flatMap {
                    Self.dateFormatter.date(from: $0) ?? Self.fallbackDateFormatter.date(from: $0)
                }
            )
        }
    }

    func report(artworkID: UUID, reason: CommunityReportReason, details: String) async throws {
        let endpoint = configuration.url.appendingPathComponent("functions/v1/community-report")
        var request = authorizedRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            CommunityReportDTO(
                artworkID: artworkID,
                installationID: CommunityInstallationIdentity.current(),
                reason: reason.rawValue,
                details: details
            )
        )

        _ = try await responseData(for: request)
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommunityRepositoryError.invalidResponse
        }

        guard !(200..<300).contains(httpResponse.statusCode) else { return }

        let code = (try? decoder.decode(FunctionErrorDTO.self, from: data))?.error
        switch code {
        case "rate_limited": throw CommunityRepositoryError.rateLimited
        case "submissions_unavailable": throw CommunityRepositoryError.submissionsUnavailable
        case "artwork_unavailable": throw CommunityRepositoryError.artworkUnavailable
        default: throw CommunityRepositoryError.requestFailed
        }
    }

    private func makeArtwork(_ row: CommunityArtworkDTO) -> CommunityArtwork? {
        guard let date = Self.dateFormatter.date(from: row.publishedAt) ?? Self.fallbackDateFormatter.date(from: row.publishedAt) else {
            return nil
        }

        let encodedPath = row.imagePath
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        let imageURL = configuration.url
            .appendingPathComponent("storage/v1/object/public/community-artworks")
            .appendingPathComponent(encodedPath)
            .absoluteString

        return CommunityArtwork(
            id: row.id,
            contributorID: row.contributorID,
            title: row.title,
            creatorName: row.creatorName,
            significance: row.significance,
            category: row.category,
            imageURL: imageURL,
            publishedAt: date
        )
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatter = ISO8601DateFormatter()
}

private struct CommunityArtworkDTO: Decodable {
    let id: UUID
    let contributorID: UUID
    let title: String
    let creatorName: String
    let significance: String
    let category: CultureCategory
    let imagePath: String
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case contributorID = "contributor_id"
        case title
        case creatorName = "creator_name"
        case significance
        case category
        case imagePath = "image_path"
        case publishedAt = "published_at"
    }
}

private struct SubmissionReceiptDTO: Decodable {
    let id: UUID
}

private struct SubmissionStatusRequestDTO: Encodable {
    let installationID: UUID
    let ids: [UUID]

    enum CodingKeys: String, CodingKey {
        case installationID = "installation_id"
        case ids
    }
}

private struct SubmissionStatusResponseDTO: Decodable {
    let submissions: [SubmissionStatusDTO]
}

private struct SubmissionStatusDTO: Decodable {
    let id: UUID
    let status: CommunitySubmissionReviewStatus
    let reviewedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case reviewedAt = "reviewed_at"
    }
}

private struct FunctionErrorDTO: Decodable {
    let error: String
}

private struct CommunityReportDTO: Encodable {
    let artworkID: UUID
    let installationID: UUID
    let reason: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case artworkID = "artwork_id"
        case installationID = "installation_id"
        case reason
        case details
    }
}

private struct MultipartFormData {
    let boundary: String
    private var parts: [Data] = []

    init(boundary: String) {
        self.boundary = boundary
    }

    func adding(name: String, value: String) -> MultipartFormData {
        var copy = self
        var data = Data()
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        data.append("\(value)\r\n")
        copy.parts.append(data)
        return copy
    }

    func adding(name: String, filename: String, contentType: String, data fileData: Data) -> MultipartFormData {
        var copy = self
        var data = Data()
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        data.append("Content-Type: \(contentType)\r\n\r\n")
        data.append(fileData)
        data.append("\r\n")
        copy.parts.append(data)
        return copy
    }

    func encoded() -> Data {
        var data = parts.reduce(into: Data()) { $0.append($1) }
        data.append("--\(boundary)--\r\n")
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

private enum CommunityInstallationIdentity {
    private static let service = "com.sam.HumanCollective.community"
    private static let account = "installation-id"
    private static let fallbackKey = "humanCulture.communityInstallationID"

    static func current() -> UUID {
        if let stored = readKeychain(), let id = UUID(uuidString: stored) {
            return id
        }

        if let stored = UserDefaults.standard.string(forKey: fallbackKey), let id = UUID(uuidString: stored) {
            saveKeychain(stored)
            return id
        }

        let id = UUID()
        let value = id.uuidString.lowercased()
        saveKeychain(value)
        UserDefaults.standard.set(value, forKey: fallbackKey)
        return id
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func saveKeychain(_ value: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]

        if SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }
}
