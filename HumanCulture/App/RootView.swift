import SwiftUI

struct RootView: View {
    let repository: any CultureRepository
    let savedStore: SavedStore

    @AppStorage("humanCulture.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView(repository: repository, savedStore: savedStore)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .tint(HCTheme.blueStone)
    }
}

private struct MainTabView: View {
    let repository: any CultureRepository
    let savedStore: SavedStore

    var body: some View {
        TabView {
            NavigationStack {
                ThisWeekView(repository: repository, savedStore: savedStore)
            }
            .tabItem {
                Label("This Week", systemImage: "sun.max")
            }

            NavigationStack {
                ArchiveView(repository: repository, savedStore: savedStore)
            }
            .tabItem {
                Label("Archive", systemImage: "books.vertical")
            }

            NavigationStack {
                SavedView(savedStore: savedStore)
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
        }
    }
}

