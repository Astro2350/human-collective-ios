import SwiftUI
import UIKit

@main
@MainActor
struct HumanCollectiveApp: App {
    @State private var savedStore = SavedStore()
    private let repository: any CultureRepository = CultureRepositoryFactory.make()

    init() {
        AppChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository, savedStore: savedStore)
                .preferredColorScheme(.light)
        }
    }
}

private enum AppChrome {
    static func configure() {
        let background = UIColor(red: 0.963, green: 0.948, blue: 0.918, alpha: 1)
        let tabBackground = UIColor.white
        let ink = UIColor.black
        let line = UIColor(red: 0.802, green: 0.755, blue: 0.650, alpha: 0.55)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = tabBackground
        tabAppearance.shadowColor = line
        tabAppearance.stackedLayoutAppearance = tabItemAppearance(ink: ink)
        tabAppearance.inlineLayoutAppearance = tabItemAppearance(ink: ink)
        tabAppearance.compactInlineLayoutAppearance = tabItemAppearance(ink: ink)
        UITabBar.appearance().overrideUserInterfaceStyle = .light
        UITabBar.appearance().backgroundColor = tabBackground
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().barTintColor = tabBackground
        UITabBar.appearance().tintColor = ink
        UITabBar.appearance().unselectedItemTintColor = ink
        UITabBar.appearance().isTranslucent = false

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = background
        navigationAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
    }

    private static func tabItemAppearance(ink: UIColor) -> UITabBarItemAppearance {
        let appearance = UITabBarItemAppearance()
        appearance.normal.iconColor = ink
        appearance.normal.titleTextAttributes = [.foregroundColor: ink]
        appearance.selected.iconColor = ink
        appearance.selected.titleTextAttributes = [.foregroundColor: ink]
        return appearance
    }
}
