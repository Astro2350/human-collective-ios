import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

struct GetDailyArtifactWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Daily Artifact Wallpaper"
    static let description = IntentDescription(
        "Creates a phone wallpaper from today's Human Collective artifact, including its name."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let pack = try await CultureRepositoryFactory.make().fetchCurrentPack()
        guard let selection = pack.dailySelection() else {
            throw DailyArtifactWallpaperError.missingArtifact
        }

        let item = selection.item
        guard let imageURL = URL(string: item.imageURL) else {
            throw DailyArtifactWallpaperError.invalidImageURL
        }

        var request = URLRequest(url: imageURL)
        request.timeoutInterval = 30
        request.setValue("HumanCollective/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let sourceImage = ArtifactImageProcessor.thumbnailImage(from: data, maximumDimension: 4096) else {
            throw DailyArtifactWallpaperError.imageDownloadFailed
        }

        let wallpaper = await DailyArtifactWallpaperRenderer.render(
            image: sourceImage,
            title: item.displayTitle,
            detail: item.cardMetadataDisplay
        )
        guard let wallpaperData = wallpaper.jpegData(compressionQuality: 0.94) else {
            throw DailyArtifactWallpaperError.renderFailed
        }

        let slug = Self.filenameSlug(item.displayTitle)
        let filename = "human-collective-\(slug.isEmpty ? "daily-artifact" : slug).jpg"
        let file = IntentFile(data: wallpaperData, filename: filename, type: .jpeg)
        return .result(value: file, dialog: "Created today's wallpaper for \(item.displayTitle).")
    }

    private static func filenameSlug(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return title
            .lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .prefix(48)
            .description
    }
}

struct HumanCollectiveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDailyArtifactWallpaperIntent(),
            phrases: [
                "Get today's wallpaper from \(.applicationName)",
                "Make my daily artifact wallpaper with \(.applicationName)"
            ],
            shortTitle: "Daily Artifact Wallpaper",
            systemImageName: "photo.on.rectangle.angled"
        )
    }
}

private enum DailyArtifactWallpaperError: LocalizedError {
    case missingArtifact
    case invalidImageURL
    case imageDownloadFailed
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .missingArtifact:
            "Today's artifact is not available yet."
        case .invalidImageURL:
            "Today's artifact has an invalid image URL."
        case .imageDownloadFailed:
            "The artifact image could not be downloaded."
        case .renderFailed:
            "The wallpaper image could not be created."
        }
    }
}

@MainActor
enum DailyArtifactWallpaperRenderer {
    static let canvasSize = CGSize(width: 1290, height: 2796)
    static let titleRect = CGRect(x: 94, y: canvasSize.height - 820, width: canvasSize.width - 188, height: 560)

    struct TitleLayout {
        let text: String
        let font: UIFont
    }

    static func render(image: UIImage, title: String, detail: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let canvas = CGRect(origin: .zero, size: canvasSize)
            UIColor(red: 0.055, green: 0.05, blue: 0.045, alpha: 1).setFill()
            context.fill(canvas)

            image.draw(in: aspectFillRect(for: image.size, in: canvas))

            let colors = [
                UIColor.black.withAlphaComponent(0.08).cgColor,
                UIColor.black.withAlphaComponent(0.18).cgColor,
                UIColor.black.withAlphaComponent(0.88).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.52, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: canvas.midX, y: canvas.minY),
                    end: CGPoint(x: canvas.midX, y: canvas.maxY),
                    options: []
                )
            }

            drawText("HUMAN COLLECTIVE", font: .systemFont(ofSize: 32, weight: .bold), tracking: 5.5,
                     color: UIColor.white.withAlphaComponent(0.82),
                     in: CGRect(x: 94, y: 208, width: canvas.width - 188, height: 60))

            let titleLayout = titleLayout(for: title, constrainedTo: titleRect.size)
            drawText(titleLayout.text, font: titleLayout.font, tracking: 0,
                     color: .white,
                     in: titleRect)

            if !detail.isEmpty {
                drawText(detail.uppercased(), font: .systemFont(ofSize: 30, weight: .semibold), tracking: 2.4,
                         color: UIColor.white.withAlphaComponent(0.76),
                         in: CGRect(x: 94, y: canvas.height - 285, width: canvas.width - 188, height: 80))
            }
        }
    }

    private static func aspectFillRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    static func titleLayout(for rawTitle: String, constrainedTo proposedBoundsSize: CGSize? = nil) -> TitleLayout {
        let boundsSize = proposedBoundsSize ?? titleRect.size
        let normalizedTitle = rawTitle
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        let title = normalizedTitle.isEmpty ? "Today's Artifact" : normalizedTitle

        for pointSize in stride(from: CGFloat(104), through: CGFloat(26), by: -2) {
            let font = UIFont.systemFont(ofSize: pointSize, weight: .bold)
            if textFits(title, font: font, constrainedTo: boundsSize) {
                return TitleLayout(text: title, font: font)
            }
        }

        let minimumFont = UIFont.systemFont(ofSize: 26, weight: .bold)
        let characters = Array(title)
        var lowerBound = 1
        var upperBound = characters.count
        var fittingText = "…"

        while lowerBound <= upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            let candidate = String(characters.prefix(midpoint)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
            if textFits(candidate, font: minimumFont, constrainedTo: boundsSize) {
                fittingText = candidate
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint - 1
            }
        }
        return TitleLayout(text: fittingText, font: minimumFont)
    }

    static func textFits(_ text: String, font: UIFont, constrainedTo boundsSize: CGSize) -> Bool {
        let measurementSize = CGSize(width: boundsSize.width, height: .greatestFiniteMagnitude)
        let bounds = (text as NSString).boundingRect(
            with: measurementSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: titleParagraphStyle],
            context: nil
        )
        return ceil(bounds.width) <= boundsSize.width && ceil(bounds.height) <= boundsSize.height
    }

    private static var titleParagraphStyle: NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 5
        return paragraph
    }

    private static func drawText(
        _ text: String,
        font: UIFont,
        tracking: CGFloat,
        color: UIColor,
        in rect: CGRect
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 5

        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .kern: tracking,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}
