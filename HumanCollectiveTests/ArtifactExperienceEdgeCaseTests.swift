import XCTest
import UIKit
@testable import Human_Collective

final class ArtifactExperienceEdgeCaseTests: XCTestCase {
    func testDailySelectionChangesAtLocalMidnightIncludingDSTWeek() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))

        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12)))
        let beforeMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 59)))
        let afterMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 1)))

        XCTAssertEqual(DailyArtifactDaySelector.index(startDate: start, on: beforeMidnight, itemCount: 7, calendar: calendar), 1)
        XCTAssertEqual(DailyArtifactDaySelector.index(startDate: start, on: afterMidnight, itemCount: 7, calendar: calendar), 2)
        XCTAssertEqual(DailyArtifactDaySelector.index(startDate: start, on: start.addingTimeInterval(-86_400), itemCount: 7, calendar: calendar), 0)
        XCTAssertEqual(DailyArtifactDaySelector.index(startDate: start, on: start.addingTimeInterval(20 * 86_400), itemCount: 7, calendar: calendar), 6)
        XCTAssertNil(DailyArtifactDaySelector.index(startDate: start, on: start, itemCount: 0, calendar: calendar))
    }

    func testThumbnailDecoderBoundsVeryLargeLandscapeAndPortraitImages() throws {
        let cases: [(CGSize, CGFloat)] = [
            (CGSize(width: 10_000, height: 320), 320),
            (CGSize(width: 320, height: 10_000), 320),
            (CGSize(width: 4_000, height: 4_000), 900)
        ]

        for (sourceSize, maximumDimension) in cases {
            let sourceData = try XCTUnwrap(makeJPEG(size: sourceSize))
            let resultData = try XCTUnwrap(
                ArtifactImageProcessor.jpegThumbnailData(
                    from: sourceData,
                    maximumDimension: maximumDimension
                )
            )
            let result = try XCTUnwrap(UIImage(data: resultData))
            XCTAssertLessThanOrEqual(max(result.size.width, result.size.height), maximumDimension)
            XCTAssertGreaterThan(result.size.width, 0)
            XCTAssertGreaterThan(result.size.height, 0)
        }
    }

    func testThumbnailDecoderRejectsInvalidImageData() {
        XCTAssertNil(
            ArtifactImageProcessor.jpegThumbnailData(
                from: Data("not an image".utf8),
                maximumDimension: 320
            )
        )
    }

    @MainActor
    func testWallpaperKeepsLongRealisticTitleAndProducesPhoneCanvas() throws {
        let title = Array(repeating: "Ceremonial Vessel with Birds, Ancestors, Spirals, and Celestial Motifs", count: 4)
            .joined(separator: " — ")
        let layout = DailyArtifactWallpaperRenderer.titleLayout(for: title)

        XCTAssertEqual(layout.text, title)
        XCTAssertTrue(
            DailyArtifactWallpaperRenderer.textFits(
                layout.text,
                font: layout.font,
                constrainedTo: DailyArtifactWallpaperRenderer.titleRect.size
            )
        )

        let wallpaper = DailyArtifactWallpaperRenderer.render(
            image: makeImage(size: CGSize(width: 5_000, height: 360)),
            title: title,
            detail: "Mesoamerica — 200 BCE–300 CE"
        )
        XCTAssertEqual(wallpaper.size, DailyArtifactWallpaperRenderer.canvasSize)
        XCTAssertNotNil(wallpaper.jpegData(compressionQuality: 0.94))
        let attachment = XCTAttachment(image: wallpaper)
        attachment.name = "Long-title panoramic wallpaper"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWallpaperSafelyEllipsizesPathologicalTitle() {
        let title = String(repeating: "𓂀ExtremelyLongArtifactNameWithoutNaturalBreaks", count: 250)
        let layout = DailyArtifactWallpaperRenderer.titleLayout(for: title)

        XCTAssertTrue(layout.text.hasSuffix("…"))
        XCTAssertLessThan(layout.text.count, title.count)
        XCTAssertTrue(
            DailyArtifactWallpaperRenderer.textFits(
                layout.text,
                font: layout.font,
                constrainedTo: DailyArtifactWallpaperRenderer.titleRect.size
            )
        )
    }

    @MainActor
    func testWallpaperUsesFallbackForWhitespaceOnlyTitle() {
        let layout = DailyArtifactWallpaperRenderer.titleLayout(for: "  \n\t  ")
        XCTAssertEqual(layout.text, "Today's Artifact")
    }

    @MainActor
    func testLiveDailyWallpaperIntentBuildsCurrentArtifact() async throws {
        _ = try await GetDailyArtifactWallpaperIntent().perform()
    }

    private func makeJPEG(size: CGSize) -> Data? {
        makeImage(size: size).jpegData(compressionQuality: 0.82)
    }

    private func makeImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.17, green: 0.35, blue: 0.43, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.78, green: 0.47, blue: 0.28, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.6))
        }
    }
}
