import Foundation
import Observation

struct ProfileSubmissionReceipt: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let creatorName: String
    let category: CultureCategory
    let submittedAt: Date
    var status: CommunitySubmissionReviewStatus
    var reviewedAt: Date?
}

struct PersonalExhibition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var items: [CultureItem]
    let createdAt: Date
}

@MainActor
@Observable
final class ProfileStore {
    private(set) var displayName: String
    private(set) var submissions: [ProfileSubmissionReceipt]
    private(set) var exhibitions: [PersonalExhibition]
    private(set) var revision = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let nameKey = "humanCulture.profile.displayName"
    @ObservationIgnored private let submissionsKey = "humanCulture.profile.submissions"
    @ObservationIgnored private let exhibitionsKey = "humanCulture.profile.exhibitions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displayName = defaults.string(forKey: nameKey) ?? ""
        self.submissions = Self.decode([ProfileSubmissionReceipt].self, key: submissionsKey, defaults: defaults) ?? []
        self.exhibitions = Self.decode([PersonalExhibition].self, key: exhibitionsKey, defaults: defaults) ?? []
    }

    var displayNameOrFallback: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your Profile" : trimmed
    }

    func updateDisplayName(_ value: String) {
        let normalized = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(normalized.prefix(60))
        guard clipped != displayName else { return }
        displayName = clipped
        defaults.set(clipped, forKey: nameKey)
        revision += 1
    }

    func recordSubmission(id: UUID, draft: CommunitySubmissionDraft) {
        guard !submissions.contains(where: { $0.id == id }) else { return }

        submissions.insert(
            ProfileSubmissionReceipt(
                id: id,
                title: draft.title,
                creatorName: draft.creatorName,
                category: draft.category,
                submittedAt: Date(),
                status: .pending,
                reviewedAt: nil
            ),
            at: 0
        )
        persistSubmissions()

        if displayName.isEmpty,
           draft.creatorName.localizedCaseInsensitiveCompare("Unknown") != .orderedSame {
            updateDisplayName(draft.creatorName)
        }
    }

    func mergeSubmissionStatuses(_ statuses: [CommunitySubmissionStatus]) {
        let statusByID = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        var changed = false

        submissions = submissions.map { receipt in
            guard let remote = statusByID[receipt.id],
                  receipt.status != remote.status || receipt.reviewedAt != remote.reviewedAt else {
                return receipt
            }

            var updated = receipt
            updated.status = remote.status
            updated.reviewedAt = remote.reviewedAt
            changed = true
            return updated
        }

        guard changed else { return }
        persistSubmissions()
    }

    func createExhibition(title: String, items: [CultureItem]) {
        let normalizedTitle = title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueItems = items.reduce(into: [CultureItem]()) { result, item in
            guard !result.contains(where: { $0.id == item.id }) else { return }
            result.append(item)
        }
        guard normalizedTitle.count >= 2, uniqueItems.count >= 2 else { return }

        exhibitions.insert(
            PersonalExhibition(
                id: UUID(),
                title: String(normalizedTitle.prefix(80)),
                items: Array(uniqueItems.prefix(12)),
                createdAt: Date()
            ),
            at: 0
        )
        persistExhibitions()
    }

    func deleteExhibition(_ exhibition: PersonalExhibition) {
        let previousCount = exhibitions.count
        exhibitions.removeAll { $0.id == exhibition.id }
        guard exhibitions.count != previousCount else { return }
        persistExhibitions()
    }

    private func persistSubmissions() {
        persist(submissions, key: submissionsKey)
    }

    private func persistExhibitions() {
        persist(exhibitions, key: exhibitionsKey)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
        revision += 1
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
