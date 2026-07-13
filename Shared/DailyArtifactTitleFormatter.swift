import Foundation

enum DailyArtifactTitleFormatter {
    private static let idealLimit = 46
    private static let displayTitleCache = NSCache<NSString, NSString>()

    static func displayTitle(from title: String) -> String {
        let cacheKey = title as NSString
        if let cachedTitle = displayTitleCache.object(forKey: cacheKey) {
            return cachedTitle as String
        }

        let displayTitle = makeDisplayTitle(from: title)
        displayTitleCache.setObject(displayTitle as NSString, forKey: cacheKey)
        return displayTitle
    }

    private static func makeDisplayTitle(from title: String) -> String {
        let normalizedTitle = normalized(title)

        if let override = curatedShortTitles[normalizedTitle] {
            return override
        }

        guard normalizedTitle.count > idealLimit else {
            return normalizedTitle
        }

        let deparenthesizedTitle = normalized(removingParentheticals(from: normalizedTitle))
        let candidates = [
            deparenthesizedTitle,
            prefix(before: ", from ", in: deparenthesizedTitle),
            prefix(before: ", Page from ", in: deparenthesizedTitle),
            prefix(before: ", plate ", in: deparenthesizedTitle),
            prefix(before: ", folio ", in: deparenthesizedTitle),
            prefix(before: ", no. ", in: deparenthesizedTitle),
            prefix(before: ", Possibly ", in: deparenthesizedTitle),
            prefix(before: ", with later ", in: deparenthesizedTitle),
            prefix(before: ", the ", in: deparenthesizedTitle),
            prefix(before: ", and ", in: deparenthesizedTitle),
            prefix(before: ", ", in: deparenthesizedTitle),
            prefix(before: ": ", in: deparenthesizedTitle)
        ]

        if let bestCandidate = candidates.compactMap({ $0 }).first(where: isUsefulTitle) {
            return bestCandidate
        }

        return wordBoundaryTrim(deparenthesizedTitle, limit: idealLimit)
    }

    private static let curatedShortTitles = [
        "Miniature Mountain with Shoulao (God of Longevity), the Eight Daoist Immortals, Scholars on Horseback, Monkey with Peach, and Deer with Mushroom of Immortality": "Miniature Mountain with Shoulao",
        "The Young Emperor Akbar Arrests the Insolent Shah Abu’l-Maali, Page from a Manuscript of the Akbarnama": "Akbar Arrests Shah Abu’l-Maali",
        "Enthroned Rama and Sita receive homage from their monkey and bear Allies, from the Yuddha Kanda (Book of the War) of a Ramayana (Rama’s Journey)": "Rama and Sita Receive Homage",
        "The Elephant of Maharana Jai Singh of Mewar (r. 1680–98) Catches a Horse by the Tail": "Elephant Catches a Horse by the Tail",
        "Two Landscapes with Dog, Putti, Rat, Cat, and Urn Border, folio 41 (recto), from Florilegium (A Book of Flower Studies)": "Two Landscapes with Animal Border",
        "The Same Man Throws a Bull in the Ring at Madrid, plate 16 from The Art of Bullfighting": "Man Throws a Bull in the Ring",
        "The Forceful Rendón Stabs a Bull with the Pique, from which Pass He Died in the Ring at Madrid, plate 28 from The Art of Bullfighting": "Rendón Stabs a Bull with the Pique",
        "Circassian Cavalry Awaiting their Commanding Officer at the Door of a Byzantine Monument; Memory of the Orient": "Circassian Cavalry at a Monument",
        "Jar, scales and bowl, no. 6 from the series \"The Rabbit's Boastful Exploits (Usagi tegarabanashi)\"": "The Rabbit's Boastful Exploits",
        "Tulips with Poppy, Carnation, Snail, Bug, and Frog Border, folio 3 (recto), from Florilegium (A Book of Flower Studies)": "Tulips with Snail and Frog Border"
    ]

    private static func normalized(_ title: String) -> String {
        title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removingParentheticals(from title: String) -> String {
        title.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func prefix(before marker: String, in title: String) -> String? {
        guard let range = title.range(of: marker, options: [.caseInsensitive]) else {
            return nil
        }

        return normalized(String(title[..<range.lowerBound]))
    }

    private static func isUsefulTitle(_ title: String) -> Bool {
        title.count >= 8 && title.count <= idealLimit
    }

    private static func wordBoundaryTrim(_ title: String, limit: Int) -> String {
        guard title.count > limit else { return title }

        let index = title.index(title.startIndex, offsetBy: limit)
        let prefix = String(title[..<index])

        if let lastSpace = prefix.lastIndex(where: { $0 == " " }) {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        }

        return prefix.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
