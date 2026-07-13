import Foundation

enum DailyArtifactDaySelector {
    static func index(
        startDate: Date,
        on date: Date,
        itemCount: Int,
        calendar: Calendar
    ) -> Int? {
        guard itemCount > 0 else { return nil }
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        let rawDayOffset = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return min(max(rawDayOffset, 0), itemCount - 1)
    }
}
