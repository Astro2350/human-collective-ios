import Foundation
import Observation

@MainActor
@Observable
final class CultureCatalogStore {
    private(set) var items: [CultureItem] = []
    private(set) var isLoading = false

    @ObservationIgnored private var hasLoaded = false

    func load(from repository: any CultureRepository, force: Bool = false) async {
        guard force || !hasLoaded else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let currentPack = try? repository.fetchCurrentPack()
        async let archivePacks = try? repository.fetchArchivePacks()

        let currentItems = (await currentPack)?.items ?? []
        let archivedItems = (await archivePacks)?.flatMap(\.items) ?? []
        let merged = currentItems + archivedItems

        guard !merged.isEmpty else { return }
        items = Self.unique(merged)
        hasLoaded = true
    }

    var newAndNowItems: [CultureItem] {
        let threshold = Calendar.current.component(.year, from: Date()) - 10
        return items
            .compactMap { item -> (CultureItem, Int)? in
                guard let year = CultureYearEstimator.latestYear(in: item.dateDisplay), year >= threshold else {
                    return nil
                }
                return (item, year)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.displayTitle < rhs.0.displayTitle }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }

    func randomItem(excluding excludedID: String? = nil, fallback: [CultureItem] = []) -> CultureItem? {
        let source = items.isEmpty ? Self.unique(fallback) : items
        let candidates = source.filter { $0.id != excludedID }
        return candidates.randomElement() ?? source.first
    }

    func relatedItems(to item: CultureItem, limit: Int = 3) -> [CultureItem] {
        items
            .filter { $0.id != item.id }
            .map { candidate in
                (candidate, relationshipScore(candidate, to: item))
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.displayTitle < rhs.0.displayTitle }
                return lhs.1 > rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private func relationshipScore(_ candidate: CultureItem, to item: CultureItem) -> Int {
        var score = 0
        if candidate.category == item.category { score += 5 }
        if Self.same(candidate.country, item.country) { score += 4 }
        if Self.same(candidate.culture, item.culture) { score += 3 }
        if Self.same(candidate.region, item.region) { score += 2 }

        if let candidateYear = CultureYearEstimator.latestYear(in: candidate.dateDisplay),
           let itemYear = CultureYearEstimator.latestYear(in: item.dateDisplay) {
            let distance = abs(candidateYear - itemYear)
            if distance <= 50 { score += 3 }
            else if distance <= 200 { score += 2 }
            else if distance <= 500 { score += 1 }
        }
        return score
    }

    private static func same(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = lhs?.trimmingCharacters(in: .whitespacesAndNewlines),
              let rhs = rhs?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lhs.isEmpty, !rhs.isEmpty else {
            return false
        }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedSame
    }

    private static func unique(_ items: [CultureItem]) -> [CultureItem] {
        items.reduce(into: [CultureItem]()) { result, item in
            guard !result.contains(where: { $0.id == item.id }) else { return }
            result.append(item)
        }
    }
}

enum CultureYearEstimator {
    private static let numberRegex = try? NSRegularExpression(pattern: #"\d{1,4}"#)

    static func latestYear(in text: String) -> Int? {
        let lowercase = text.lowercased()
        guard let regex = numberRegex else { return nil }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        let numbers = matches.compactMap { Int(nsText.substring(with: $0.range)) }
        guard !numbers.isEmpty else { return nil }

        if lowercase.contains("century"), let century = numbers.first, century <= 40 {
            let estimatedYear = ((century - 1) * 100) + 75
            if lowercase.contains("bce") || lowercase.range(of: #"\bbc\b"#, options: .regularExpression) != nil {
                return -estimatedYear
            }
            return estimatedYear
        }

        if lowercase.contains("bce") || lowercase.range(of: #"\bbc\b"#, options: .regularExpression) != nil {
            return -numbers.min()!
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        return numbers.filter { $0 <= currentYear }.max()
    }
}
