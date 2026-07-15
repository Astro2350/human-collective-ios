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

@MainActor
@Observable
final class ProfileStore {
    private(set) var submissions: [ProfileSubmissionReceipt]
    private(set) var revision = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let submissionsKey = "humanCulture.profile.submissions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.submissions = Self.decode(
            [ProfileSubmissionReceipt].self,
            key: submissionsKey,
            defaults: defaults
        ) ?? []
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

    private func persistSubmissions() {
        if let data = try? JSONEncoder().encode(submissions) {
            defaults.set(data, forKey: submissionsKey)
        }
        revision += 1
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
