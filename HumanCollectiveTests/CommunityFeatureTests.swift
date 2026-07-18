import ImageIO
import UIKit
import XCTest
@testable import Human_Collective

final class CommunityFeatureTests: XCTestCase {
    func testCommunityArtworkCreatesStableSavedSnapshot() {
        let artworkID = UUID(uuidString: "BC4DCFB4-299D-46B0-8E06-320E54F893C3")!
        let artwork = CommunityArtwork(
            id: artworkID,
            contributorID: UUID(),
            title: "A New Chair",
            creatorName: "Sam",
            significance: "A clear explanation of why this chair matters to human culture.",
            category: .furniture,
            imageURL: "https://example.com/chair.jpg",
            publishedAt: Date(timeIntervalSince1970: 1_783_987_200)
        )

        let savedItem = artwork.savedCultureItem

        XCTAssertEqual(savedItem.id, "collective-bc4dcfb4-299d-46b0-8e06-320e54f893c3")
        XCTAssertEqual(savedItem.title, artwork.title)
        XCTAssertEqual(savedItem.creatorDisplay, artwork.creatorName)
        XCTAssertEqual(savedItem.whyItMatters, artwork.significance)
        XCTAssertEqual(savedItem.category, artwork.category)
        XCTAssertEqual(savedItem.imageURL, artwork.imageURL)
        XCTAssertEqual(savedItem.sourceName, "The Human Collective")
        XCTAssertEqual(savedItem.weekKey, "collective")
    }

    func testCommunityCategoriesHaveStablePublicValues() {
        let publicValues = Set(CultureCategory.allCases.map(\.rawValue))
        XCTAssertTrue([
            "meme", "painting", "sculpture", "architecture", "car", "watch", "furniture", "fashion",
            "food", "drink", "instrument", "invention", "machine", "tool", "film", "music",
            "game", "book", "monument", "public_space", "engineering_feat"
        ].allSatisfy(publicValues.contains))
        XCTAssertEqual(CultureCategory.collectiveCases.first, .meme)
        XCTAssertEqual(CultureCategory.meme.title, "Memes")
        XCTAssertEqual(CultureCategory.engineeringFeat.title, "Engineering Feats")
    }

    func testCollectiveCategoriesUseAvailableSystemSymbols() {
        for category in CultureCategory.collectiveCases {
            XCTAssertNotNil(
                UIImage(systemName: category.symbolName),
                "Missing system symbol for \(category.rawValue): \(category.symbolName)"
            )
        }
    }

    func testSubmissionValidationExplainsTheFirstMissingRequirement() {
        XCTAssertEqual(
            CommunitySubmissionValidator.message(
                jpegData: nil,
                title: "Handmade Bowl",
                creatorName: "Sam",
                significance: String(repeating: "a", count: 40),
                rightsConfirmed: true
            ),
            "Choose a photo of the creation."
        )

        XCTAssertEqual(
            CommunitySubmissionValidator.message(
                jpegData: Data([0x01]),
                title: "Handmade Bowl",
                creatorName: "Sam",
                significance: "Too short",
                rightsConfirmed: true
            ),
            "Add a little more about why it matters (40 characters minimum)."
        )
    }

    func testSubmissionValidationRequiresArtworkTitle() {
        XCTAssertEqual(
            CommunitySubmissionValidator.message(
                jpegData: Data([0x01]),
                title: "",
                creatorName: "Sam",
                significance: String(repeating: "a", count: 40),
                rightsConfirmed: true
            ),
            "Add the artwork title."
        )
    }

    func testSubmissionValidationAcceptsACompleteDraft() {
        XCTAssertNil(
            CommunitySubmissionValidator.message(
                jpegData: Data([0x01]),
                title: "Handmade Bowl",
                creatorName: "Sam",
                significance: String(repeating: "a", count: 40),
                rightsConfirmed: true
            )
        )
    }

    func testImageProcessorCreatesBoundedJPEGAndRemovesMetadata() throws {
        let sourceJPEG = try XCTUnwrap(makeJPEG(size: CGSize(width: 4_800, height: 3_200)))
        let output = try CommunityImageProcessor.prepareJPEG(from: sourceJPEG)

        XCTAssertLessThanOrEqual(output.count, CommunityImageProcessor.maximumUploadBytes)

        let image = try XCTUnwrap(UIImage(data: output))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), CGFloat(CommunityImageProcessor.maximumDimension))

        let outputSource = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any]
        )
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }

    func testImageProcessorAcceptsSmallPortraitLandscapeAndSquarePhotos() throws {
        let sourceSizes = [
            CGSize(width: 420, height: 900),
            CGSize(width: 900, height: 420),
            CGSize(width: 640, height: 640),
        ]

        for sourceSize in sourceSizes {
            let source = try XCTUnwrap(makeJPEG(size: sourceSize))
            let output = try CommunityImageProcessor.prepareJPEG(from: source)
            let image = try XCTUnwrap(UIImage(data: output))

            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
            XCTAssertLessThanOrEqual(output.count, CommunityImageProcessor.maximumUploadBytes)
        }
    }

    @MainActor
    func testBlockedContributorPersistsLocally() {
        let suiteName = "CommunityFeatureTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let contributorID = UUID()
        let firstStore = BlockedCommunityStore(defaults: defaults)
        firstStore.block(contributorID)

        XCTAssertTrue(firstStore.contains(contributorID))
        XCTAssertTrue(BlockedCommunityStore(defaults: defaults).contains(contributorID))
    }

    @MainActor
    func testProfilePersistsSubmissionAndReviewStatusWithoutAnAccount() {
        let suiteName = "ProfileStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let submissionID = UUID()
        let imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: imageDirectory) }

        let store = ProfileStore(defaults: defaults, imagesDirectory: imageDirectory)
        store.recordSubmission(
            receipt: CommunitySubmissionReceipt(
                id: submissionID,
                imageURL: "https://example.com/submission.jpg"
            ),
            draft: CommunitySubmissionDraft(
                title: "A Useful Object",
                creatorName: "Sam Beyzer",
                significance: "A thoughtful explanation of why this object matters to human culture.",
                category: .design,
                jpegData: Data([0x01]),
                rightsConfirmed: true
            )
        )
        store.mergeSubmissionStatuses([
            CommunitySubmissionStatus(
                id: submissionID,
                status: .approved,
                reviewedAt: Date(timeIntervalSince1970: 100),
                imageURL: "https://example.com/published.jpg"
            )
        ])

        let reloaded = ProfileStore(defaults: defaults, imagesDirectory: imageDirectory)
        XCTAssertEqual(reloaded.submissions.first?.id, submissionID)
        XCTAssertEqual(reloaded.submissions.first?.creatorName, "Sam Beyzer")
        XCTAssertEqual(reloaded.submissions.first?.category, .design)
        XCTAssertEqual(reloaded.submissions.first?.status, .approved)
        XCTAssertEqual(reloaded.submissions.first?.reviewedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(reloaded.submissions.first?.imageURL, "https://example.com/published.jpg")
        XCTAssertEqual(reloaded.submissions.first?.significance, "A thoughtful explanation of why this object matters to human culture.")
    }

    @MainActor
    func testProfileKeepsReceiptsCreatedBeforeImagePreviewsWereAdded() throws {
        let suiteName = "LegacyProfileStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let id = UUID()
        let legacyReceipt: [[String: Any]] = [[
            "id": id.uuidString,
            "title": "Earlier Submission",
            "creatorName": "Sam Beyzer",
            "category": "sculpture",
            "submittedAt": 100.0,
            "status": "pending",
        ]]
        defaults.set(try JSONSerialization.data(withJSONObject: legacyReceipt), forKey: "humanCulture.profile.submissions")

        let store = ProfileStore(defaults: defaults)

        XCTAssertEqual(store.submissions.first?.id, id)
        XCTAssertEqual(store.submissions.first?.title, "Earlier Submission")
        XCTAssertNil(store.submissions.first?.significance)
        XCTAssertNil(store.submissions.first?.imageURL)
        XCTAssertNil(store.submissions.first?.imageFileName)
    }

    @MainActor
    func testCancellingSubmissionRemovesReceiptAndCachedPreview() throws {
        let suiteName = "CancellationProfileStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CancellationProfileStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: imageDirectory) }

        let submissionID = UUID()
        let jpegData = try XCTUnwrap(makeJPEG(size: CGSize(width: 900, height: 420)))
        let store = ProfileStore(defaults: defaults, imagesDirectory: imageDirectory)
        store.recordSubmission(
            receipt: CommunitySubmissionReceipt(
                id: submissionID,
                imageURL: "https://example.com/submission.jpg"
            ),
            draft: CommunitySubmissionDraft(
                title: "A Wide Handmade Object",
                creatorName: "Sam Beyzer",
                significance: "A thoughtful explanation of why this handmade object matters.",
                category: .design,
                jpegData: jpegData,
                rightsConfirmed: true
            )
        )

        let receipt = try XCTUnwrap(store.submissions.first)
        XCTAssertNotNil(store.previewImage(for: receipt))

        store.removeSubmission(id: submissionID)

        XCTAssertTrue(store.submissions.isEmpty)
        XCTAssertNil(store.previewImage(for: receipt))
        XCTAssertTrue(ProfileStore(defaults: defaults, imagesDirectory: imageDirectory).submissions.isEmpty)
    }

    func testNewAndNowYearParsingHandlesModernBCEAndCenturies() {
        XCTAssertEqual(CultureYearEstimator.latestYear(in: "Created yesterday, 2026"), 2026)
        XCTAssertEqual(CultureYearEstimator.latestYear(in: "200 BCE–100 BCE"), -100)
        XCTAssertEqual(CultureYearEstimator.latestYear(in: "18th century"), 1775)
        XCTAssertEqual(CultureYearEstimator.latestYear(in: "5th century BCE"), -475)
        XCTAssertNil(CultureYearEstimator.latestYear(in: "Date unknown"))
    }

    func testSurpriseShortcutRequestIsConsumedOnlyOnce() {
        _ = SurpriseIntentHandoff.consumeRequest()
        SurpriseIntentHandoff.requestSurprise()
        XCTAssertTrue(SurpriseIntentHandoff.consumeRequest())
        XCTAssertFalse(SurpriseIntentHandoff.consumeRequest())
    }

    func testArchiveSearchMatchesAcrossFieldsAndIgnoresDiacritics() {
        let item = CultureItem(
            id: "search-chair",
            title: "Café Chair",
            maker: "José Álvarez",
            culture: "Mexican",
            country: "Mexico",
            region: "Oaxaca",
            dateDisplay: "2026",
            category: .furniture,
            imageURL: "https://example.com/chair.jpg",
            sourceName: "Open Collection",
            sourceURL: "https://example.com/chair",
            license: "CC0",
            hook: "A compact chair for shared spaces.",
            story: "The chair brings local materials into a contemporary form.",
            whyItMatters: "It shows how furniture can carry regional craft into daily life.",
            latitude: nil,
            longitude: nil,
            weekKey: "2026-W29"
        )

        XCTAssertTrue(item.matchesSearch("cafe jose"))
        XCTAssertTrue(item.matchesSearch("furniture 2026"))
        XCTAssertTrue(item.matchesSearch("oaxaca craft"))
        XCTAssertFalse(item.matchesSearch("sculpture"))
        XCTAssertFalse(item.matchesSearch("   "))
    }

    func testCollectiveSearchMatchesCreatorCategoryAndSignificance() {
        let artwork = CommunityArtwork(
            id: UUID(),
            contributorID: UUID(),
            title: "Signal Chair",
            creatorName: "Sam Beyzer",
            significance: "A flat-pack experiment designed for repair and repeated use.",
            category: .furniture,
            imageURL: "https://example.com/signal-chair.jpg",
            publishedAt: Date(timeIntervalSince1970: 1_783_987_200)
        )

        XCTAssertTrue(artwork.matchesSearch("sam furniture"))
        XCTAssertTrue(artwork.matchesSearch("repair experiment"))
        XCTAssertFalse(artwork.matchesSearch("architecture"))
    }

    private func makeJPEG(size: CGSize) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.19, green: 0.38, blue: 0.46, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.6))
        }
        return image.jpegData(compressionQuality: 0.9)
    }

}
