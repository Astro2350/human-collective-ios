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
        ZStack {
            tabLayer(.thisWeek) {
                NavigationStack {
                    ThisWeekView(repository: repository, savedStore: savedStore)
                }
            }

            tabLayer(.archive) {
                NavigationStack {
                    ArchiveView(repository: repository, savedStore: savedStore)
                }
            }

            tabLayer(.saved) {
                NavigationStack {
                    SavedView(repository: repository, savedStore: savedStore)
                }
            }
        }
        .background(HCTheme.background)
        .tint(HCTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private func tabLayer<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = selectedTab == tab

        return content()
            .opacity(isSelected ? 1 : 0)
            .transaction { transaction in
                transaction.animation = nil
            }
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .zIndex(isSelected ? 1 : 0)
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
        case .thisWeek: "building.columns"
        case .archive: "books.vertical"
        case .saved: "bookmark"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    select(tab)
                } label: {
                    VStack(spacing: 3) {
                        AppTabIcon(tab: tab)

                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(HCTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background {
                        if tab == selectedTab {
                            Capsule()
                                .fill(HCTheme.ink.opacity(0.06))
                                .matchedGeometryEffect(id: "selected-tab-background", in: selectionNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(tab == selectedTab ? "Selected" : "")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(HCTheme.surface)
        .animation(tabSelectionAnimation, value: selectedTab)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HCTheme.line.opacity(0.45))
                .frame(height: HCTheme.hairline)
        }
    }

    private var tabSelectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)
    }

    private func select(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
    }
}

private struct AppTabIcon: View {
    let tab: AppTab

    var body: some View {
        Image(systemName: tab.icon)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 22, height: 18)
    }
}
