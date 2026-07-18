import Foundation
import Observation
import UIKit

struct ProfileSubmissionReceipt: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let creatorName: String
    let category: CultureCategory
    let submittedAt: Date
    let significance: String?
    var imageURL: String?
    let imageFileName: String?
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
    @ObservationIgnored private let imagesDirectory: URL

    init(
        defaults: UserDefaults = .standard,
        imagesDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.imagesDirectory = imagesDirectory ?? Self.defaultImagesDirectory
        self.submissions = Self.decode(
            [ProfileSubmissionReceipt].self,
            key: submissionsKey,
            defaults: defaults
        ) ?? []
    }

    func recordSubmission(receipt: CommunitySubmissionReceipt, draft: CommunitySubmissionDraft) {
        guard !submissions.contains(where: { $0.id == receipt.id }) else { return }

        let imageFileName = persistPreviewImage(draft.jpegData, id: receipt.id)

        submissions.insert(
            ProfileSubmissionReceipt(
                id: receipt.id,
                title: draft.title,
                creatorName: draft.creatorName,
                category: draft.category,
                submittedAt: Date(),
                significance: draft.significance,
                imageURL: receipt.imageURL,
                imageFileName: imageFileName,
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
                  receipt.status != remote.status ||
                  receipt.reviewedAt != remote.reviewedAt ||
                  (remote.imageURL != nil && receipt.imageURL != remote.imageURL) else {
                return receipt
            }

            var updated = receipt
            updated.status = remote.status
            updated.reviewedAt = remote.reviewedAt
            if let imageURL = remote.imageURL {
                updated.imageURL = imageURL
            }
            changed = true
            return updated
        }

        guard changed else { return }
        persistSubmissions()
    }

    func previewImage(for receipt: ProfileSubmissionReceipt) -> UIImage? {
        guard let imageFileName = receipt.imageFileName else { return nil }
        return UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(imageFileName).path)
    }

    func removeSubmission(id: UUID) {
        guard let receipt = submissions.first(where: { $0.id == id }) else { return }
        submissions.removeAll { $0.id == id }

        if let imageFileName = receipt.imageFileName {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(imageFileName))
        }
        persistSubmissions()
    }

    private func persistSubmissions() {
        if let data = try? JSONEncoder().encode(submissions) {
            defaults.set(data, forKey: submissionsKey)
        }
        revision += 1
    }

    private func persistPreviewImage(_ data: Data, id: UUID) -> String? {
        guard let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else {
            return nil
        }

        let maximumDimension: CGFloat = 1_200
        let scale = min(maximumDimension / max(source.size.width, source.size.height), 1)
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let preview = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let previewData = preview.jpegData(compressionQuality: 0.82) else { return nil }

        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            let fileName = "\(id.uuidString.lowercased()).jpg"
            try previewData.write(to: imagesDirectory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    private static var defaultImagesDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return root.appendingPathComponent("HumanCollective/SubmissionPreviews", isDirectory: true)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
