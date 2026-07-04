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

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = background
        navigationAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
    }
}
