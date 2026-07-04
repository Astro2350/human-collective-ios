import SwiftUI

enum HCTheme {
    static let background = Color(red: 0.965, green: 0.949, blue: 0.914)
    static let surface = Color(red: 0.992, green: 0.984, blue: 0.961)
    static let surfaceDeep = Color(red: 0.925, green: 0.894, blue: 0.835)
    static let ink = Color(red: 0.145, green: 0.132, blue: 0.112)
    static let secondaryInk = Color(red: 0.420, green: 0.388, blue: 0.330)
    static let mutedInk = Color(red: 0.580, green: 0.535, blue: 0.455)
    static let line = Color(red: 0.835, green: 0.800, blue: 0.720)
    static let moss = Color(red: 0.275, green: 0.365, blue: 0.315)
    static let clay = Color(red: 0.565, green: 0.365, blue: 0.265)
    static let blueStone = Color(red: 0.290, green: 0.365, blue: 0.430)

    static let cardRadius: CGFloat = 8
    static let pagePadding: CGFloat = 20
}

extension Font {
    static func cultureTitle(_ size: CGFloat, weight: Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func cultureText(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

