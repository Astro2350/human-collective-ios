import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CommunityImageProcessingError: LocalizedError, Equatable {
    case unreadable
    case resolutionTooLow
    case couldNotEncode
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "This photo could not be read. Please choose another image."
        case .resolutionTooLow:
            "Please choose a clearer, higher-resolution photo."
        case .couldNotEncode:
            "This photo could not be prepared for upload."
        case .fileTooLarge:
            "This photo is too large to upload. Please choose another image."
        }
    }
}

enum CommunityImageProcessor {
    static let maximumUploadBytes = 5 * 1024 * 1024
    static let maximumDimension = 3_000
    static let minimumShortEdge = 700
    static let minimumPixelCount = 1_000_000

    static func prepareJPEG(from sourceData: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw CommunityImageProcessingError.unreadable
        }

        guard min(width, height) >= minimumShortEdge,
              width * height >= minimumPixelCount else {
            throw CommunityImageProcessingError.resolutionTooLow
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw CommunityImageProcessingError.unreadable
        }

        for quality in [0.88, 0.78, 0.68] as [CGFloat] {
            if let data = jpegData(from: image, quality: quality), data.count <= maximumUploadBytes {
                return data
            }
        }

        throw CommunityImageProcessingError.fileTooLarge
    }

    private static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
