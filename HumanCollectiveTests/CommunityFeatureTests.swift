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
            "painting", "sculpture", "architecture", "car", "watch", "furniture", "fashion",
            "food", "drink", "instrument", "invention", "machine", "tool", "film", "music",
            "game", "book", "monument", "public_space", "engineering_feat"
        ].allSatisfy(publicValues.contains))
        XCTAssertEqual(CultureCategory.engineeringFeat.title, "Engineering Feats")
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
