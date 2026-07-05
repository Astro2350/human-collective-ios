import SwiftUI

enum HCTheme {
    static let background = Color(red: 0.963, green: 0.948, blue: 0.918)
    static let surface = Color(red: 0.992, green: 0.985, blue: 0.964)
    static let surfaceRaised = Color(red: 0.984, green: 0.972, blue: 0.942)
    static let surfaceDeep = Color(red: 0.912, green: 0.879, blue: 0.805)
    static let ink = Color(red: 0.120, green: 0.108, blue: 0.090)
    static let secondaryInk = Color(red: 0.365, green: 0.333, blue: 0.278)
    static let mutedInk = Color(red: 0.548, green: 0.502, blue: 0.420)
    static let line = Color(red: 0.802, green: 0.755, blue: 0.650)
    static let moss = Color(red: 0.255, green: 0.340, blue: 0.292)
    static let clay = Color(red: 0.550, green: 0.350, blue: 0.238)
    static let blueStone = Color(red: 0.270, green: 0.345, blue: 0.405)
    static let editorGold = Color(red: 0.725, green: 0.545, blue: 0.245)

    static let cardRadius: CGFloat = 8
    static let pagePadding: CGFloat = 18
    static let screenTopPadding: CGFloat = 18
    static let screenBottomPadding: CGFloat = 12
    static let screenSectionSpacing: CGFloat = 28
    static let screenTitleSize: CGFloat = 34
    static let hairline: CGFloat = 0.75
    static let feedImageAspectRatio: CGFloat = 1.18
    static let featuredImageAspectRatio: CGFloat = 1.02
    static let detailImageAspectRatio: CGFloat = 1.03
}

extension Font {
    static func cultureTitle(_ size: CGFloat, weight: Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func cultureText(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func cultureKicker(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}
