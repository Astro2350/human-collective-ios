import Foundation

extension Date {
    var cultureWeekKey: String {
        let calendar = Calendar.cultureCalendar
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        let year = components.yearForWeekOfYear ?? calendar.component(.year, from: self)
        let week = components.weekOfYear ?? 1
        return String(format: "%04d-W%02d", year, week)
    }
}

extension Calendar {
    static var cultureCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
