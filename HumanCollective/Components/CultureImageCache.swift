import Foundation
import UIKit

actor CultureImageCache {
    static let shared = CultureImageCache()

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

        let data = try await data(for: url)

        if let cachedImage = cachedImage(for: url) {
            return cachedImage
        }

        guard let image = UIImage(data: data) else {
            throw CultureImageCacheError.decodingFailed
        }

        imageCache.setObject(image, forKey: url as NSURL, cost: Self.imageCost(image))
        return image
    }

    func data(for url: URL) async throws -> Data {
        if let cachedData = cachedData(for: url) {
            return cachedData
        }

        if let task = inFlight[url] {
            return try await task.value
        }

        let task = Task(priority: .userInitiated) {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()

            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                throw CultureImageCacheError.requestFailed
            }

            return data
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
