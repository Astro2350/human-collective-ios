import Foundation

enum CultureFormatters {
    static func weekRange(startDate: Date, endDate: Date) -> String {
        let calendar = Calendar.cultureCalendar
        let sameMonth = calendar.component(.month, from: startDate) == calendar.component(.month, from: endDate)
        let sameYear = calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate)

        if sameMonth && sameYear {
            return "\(monthDayFormatter.string(from: startDate))-\(dayFormatter.string(from: endDate)), \(yearFormatter.string(from: endDate))"
        }

        if sameYear {
            return "\(monthDayFormatter.string(from: startDate))-\(monthDayFormatter.string(from: endDate)), \(yearFormatter.string(from: endDate))"
        }

        return "\(fullFormatter.string(from: startDate))-\(fullFormatter.string(from: endDate))"
    }

    static func shortWeek(startDate: Date, endDate: Date) -> String {
        "\(shortFormatter.string(from: startDate)) - \(shortFormatter.string(from: endDate))"
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

