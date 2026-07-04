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

    @State private var selectedTab: AppTab = .thisWeek

    var body: some View {
        Group {
            switch selectedTab {
            case .thisWeek:
                NavigationStack {
                    ThisWeekView(repository: repository, savedStore: savedStore, selectedTab: $selectedTab)
                }
            case .archive:
                NavigationStack {
                    ArchiveView(repository: repository, savedStore: savedStore, selectedTab: $selectedTab)
                }
            case .saved:
                NavigationStack {
                    SavedView(repository: repository, savedStore: savedStore, selectedTab: $selectedTab)
                }
            }
        }
        .background(HCTheme.background)
        .tint(.black)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

enum AppTab: CaseIterable {
    case thisWeek
    case archive
    case saved

    var title: String {
        switch self {
        case .thisWeek: "This Week"
        case .archive: "Archive"
        case .saved: "Saved"
        }
    }

    var icon: String {
        switch self {
        case .thisWeek: "sun.max"
        case .archive: "books.vertical"
        case .saved: "bookmark"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))

                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(tab == selectedTab ? Color.black.opacity(0.06) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(tab == selectedTab ? "Selected" : "")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HCTheme.line.opacity(0.45))
                .frame(height: HCTheme.hairline)
        }
    }
}
