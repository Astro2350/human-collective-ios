import Foundation

actor CultureImageCache {
    static let shared = CultureImageCache()

    private let cache = NSCache<NSURL, NSData>()
    private var inFlight: [URL: Task<Data, Error>] = [:]

    private init() {
        cache.countLimit = 140
        cache.totalCostLimit = 72 * 1024 * 1024
    }

    func cachedData(for url: URL) -> Data? {
        cache.object(forKey: url as NSURL) as Data?
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
            for url in uniqueURLs where cache.object(forKey: url as NSURL) == nil {
                group.addTask {
                    _ = try? await Self.shared.data(for: url)
                }
            }
        }
    }
}

private enum CultureImageCacheError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        "The image could not be loaded."
    }
}
