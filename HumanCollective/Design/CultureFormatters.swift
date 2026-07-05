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
        formatter("MMM d")
    }()

    private static let dayFormatter: DateFormatter = {
        formatter("d")
    }()

    private static let yearFormatter: DateFormatter = {
        formatter("yyyy")
    }()

    private static let fullFormatter: DateFormatter = {
        formatter("MMM d, yyyy")
    }()

    private static let shortFormatter: DateFormatter = {
        formatter("MMM d")
    }()

    private static func formatter(_ dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .cultureCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = dateFormat
        return formatter
    }
}
