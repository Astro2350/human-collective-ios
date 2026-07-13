import Foundation
import ImageIO
import UIKit

enum ArtifactImageProcessor {
    static func thumbnailImage(from data: Data, maximumDimension: CGFloat) -> UIImage? {
        guard maximumDimension > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(Int(maximumDimension.rounded(.up)), 1),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }

    static func jpegThumbnailData(
        from data: Data,
        maximumDimension: CGFloat,
        compressionQuality: CGFloat = 0.88
    ) -> Data? {
        thumbnailImage(from: data, maximumDimension: maximumDimension)?
            .jpegData(compressionQuality: min(max(compressionQuality, 0), 1))
    }
}
