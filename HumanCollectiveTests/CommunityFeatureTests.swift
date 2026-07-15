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
            "Choose a clear, high-resolution photo."
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

    func testImageProcessorRejectsLowResolutionPhoto() throws {
        let source = try XCTUnwrap(makeJPEG(size: CGSize(width: 640, height: 640)))

        XCTAssertThrowsError(try CommunityImageProcessor.prepareJPEG(from: source)) { error in
            XCTAssertEqual(error as? CommunityImageProcessingError, .resolutionTooLow)
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
    func testProfilePersistsNameSubmissionAndReviewStatusWithoutAnAccount() {
        let suiteName = "ProfileStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let submissionID = UUID()
        let store = ProfileStore(defaults: defaults)
        store.updateDisplayName("  Sam   Beyzer  ")
        store.recordSubmission(
            id: submissionID,
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
            CommunitySubmissionStatus(id: submissionID, status: .approved, reviewedAt: Date(timeIntervalSince1970: 100))
        ])

        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.displayName, "Sam Beyzer")
        XCTAssertEqual(reloaded.submissions.first?.id, submissionID)
        XCTAssertEqual(reloaded.submissions.first?.status, .approved)
        XCTAssertEqual(reloaded.submissions.first?.reviewedAt, Date(timeIntervalSince1970: 100))
    }

    @MainActor
    func testPersonalExhibitionRequiresTwoDistinctWorksAndPersists() {
        let suiteName = "ExhibitionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = makeCultureItem(id: "first", title: "First Work", date: "2025")
        let second = makeCultureItem(id: "second", title: "Second Work", date: "2026")
        let store = ProfileStore(defaults: defaults)

        store.createExhibition(title: "One work", items: [first, first])
        XCTAssertTrue(store.exhibitions.isEmpty)

        store.createExhibition(title: "  Things   I Saved  ", items: [first, second, first])
        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.exhibitions.first?.title, "Things I Saved")
        XCTAssertEqual(reloaded.exhibitions.first?.items.map(\.id), ["first", "second"])
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

    private func makeCultureItem(id: String, title: String, date: String) -> CultureItem {
        CultureItem(
            id: id,
            title: title,
            maker: "A Creator",
            culture: nil,
            country: "United States",
            region: nil,
            dateDisplay: date,
            category: .design,
            imageURL: "https://example.com/\(id).jpg",
            sourceName: "Example",
            sourceURL: "https://example.com/\(id)",
            license: "Public domain",
            hook: "A meaningful work worth discovering.",
            story: "A sufficiently detailed story about this meaningful work and the people who created it.",
            whyItMatters: "It influenced how people understand the designed world.",
            latitude: nil,
            longitude: nil,
            weekKey: "test"
        )
    }
}
