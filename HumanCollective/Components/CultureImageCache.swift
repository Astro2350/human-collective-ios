import Foundation
import UIKit

actor CultureImageCache {
    static let shared = CultureImageCache()

    private static let maximumDownloadAttempts = 3

    private let cache = NSCache<NSURL, NSData>()
    private let imageCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<Data, Error>] = [:]

    private init() {
        cache.countLimit = 140
        cache.totalCostLimit = 72 * 1024 * 1024
        imageCache.countLimit = 90
        imageCache.totalCostLimit = 96 * 1024 * 1024
    }

    func cachedData(for url: URL) -> Data? {
        cache.object(forKey: url as NSURL) as Data?
    }

    func cachedImage(for url: URL) -> UIImage? {
        imageCache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cachedImage = cachedImage(for: url) {
            return cachedImage
        }

        do {
            let data = try await data(for: url)

            if let cachedImage = cachedImage(for: url) {
                return cachedImage
            }

            guard let image = UIImage(data: data) else {
                throw CultureImageCacheError.decodingFailed
            }

            imageCache.setObject(image, forKey: url as NSURL, cost: Self.imageCost(image))
            return image
        } catch {
            if let fallbackImage = Self.bundledFallbackImage(for: url) {
                imageCache.setObject(fallbackImage, forKey: url as NSURL, cost: Self.imageCost(fallbackImage))
                return fallbackImage
            }

            throw error
        }
    }

    func data(for url: URL) async throws -> Data {
        if let cachedData = cachedData(for: url) {
            return cachedData
        }

        if let task = inFlight[url] {
            return try await task.value
        }

        let task = Task(priority: .userInitiated) {
            try await Self.downloadDataWithRetry(for: url)
        }

        inFlight[url] = task

        do {
            let data = try await task.value
            cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
            inFlight[url] = nil
            return data
        } catch {
            inFlight[url] = nil
            throw error
        }
    }

    func prefetch(_ urls: [URL]) async {
        let uniqueURLs = Array(Set(urls))

        await withTaskGroup(of: Void.self) { group in
            for url in uniqueURLs where imageCache.object(forKey: url as NSURL) == nil {
                group.addTask {
                    _ = try? await Self.shared.image(for: url)
                }
            }
        }
    }

    private nonisolated static func downloadDataWithRetry(for url: URL) async throws -> Data {
        var lastError: Error?

        for attempt in 1...maximumDownloadAttempts {
            do {
                return try await downloadData(for: url)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                guard attempt < maximumDownloadAttempts else { break }
                try await Task.sleep(for: .milliseconds(250 * attempt))
            }
        }

        throw lastError ?? CultureImageCacheError.requestFailed
    }

    private nonisolated static func downloadData(for url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 24
        request.setValue("HumanCollective/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("image/jpeg,image/png,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()

        if let response = response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            throw CultureImageCacheError.requestFailed
        }

        guard !data.isEmpty else {
            throw CultureImageCacheError.decodingFailed
        }

        return data
    }

    private nonisolated static func bundledFallbackImage(for url: URL) -> UIImage? {
        guard let assetName = bundledFallbackAssetName(for: url) else { return nil }
        return UIImage(named: assetName)
    }

    private nonisolated static func bundledFallbackAssetName(for url: URL) -> String? {
        if url.host?.localizedCaseInsensitiveContains("artic.edu") == true {
            let pathComponents = url.pathComponents
            if let iiifIndex = pathComponents.firstIndex(of: "iiif"),
               pathComponents.indices.contains(iiifIndex + 2),
               pathComponents[iiifIndex + 1] == "2" {
                return "ArchiveFallback_\(pathComponents[iiifIndex + 2])"
            }
        }

        return "ArchiveFallbackURL_\(fnv1a64Hex(url.absoluteString))"
    }

    private nonisolated static func fnv1a64Hex(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }

        return String(format: "%016llx", hash)
    }

    private static func imageCost(_ image: UIImage) -> Int {
        let pixelWidth = max(Int(image.size.width * image.scale), 1)
        let pixelHeight = max(Int(image.size.height * image.scale), 1)
        return pixelWidth * pixelHeight * 4
    }
}

private enum CultureImageCacheError: LocalizedError {
    case requestFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed, .decodingFailed:
            "The image could not be loaded."
        }
    }
}
