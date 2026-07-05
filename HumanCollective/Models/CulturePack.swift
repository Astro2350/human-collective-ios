import Foundation

struct CulturePack: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let weekKey: String
    let title: String
    let subtitle: String
    let startDate: Date
    let endDate: Date
    let items: [CultureItem]

    var featuredItem: CultureItem? {
        items.first
    }

    var dailyItems: [CultureItem] {
        Array(items.prefix(7))
    }

    func dailySelection(on date: Date = Date()) -> CultureDailySelection? {
        let candidates = dailyItems
        guard !candidates.isEmpty else { return nil }

        let calendar = Calendar.cultureCalendar
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        let rawDayOffset = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        let index = min(max(rawDayOffset, 0), candidates.count - 1)

        return CultureDailySelection(
            item: candidates[index],
            dayNumber: index + 1,
            totalDays: candidates.count
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case weekKey = "week_key"
        case title
        case subtitle
        case startDate = "start_date"
        case endDate = "end_date"
        case items
    }
}

struct CultureDailySelection: Hashable, Sendable {
    let item: CultureItem
    let dayNumber: Int
    let totalDays: Int
}
