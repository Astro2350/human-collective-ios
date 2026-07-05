import SwiftUI

struct RootView: View {
    let repository: any CultureRepository
    let savedStore: SavedStore
    let fullArchiveStore: FullArchiveStore

    @AppStorage("humanCulture.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var notificationManager = DailyNotificationManager()

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView(
                    repository: repository,
                    savedStore: savedStore,
                    fullArchiveStore: fullArchiveStore
                )
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .tint(HCTheme.blueStone)
        .task(id: hasCompletedOnboarding) {
            guard hasCompletedOnboarding else { return }
            await notificationManager.prepareDailyReminder()
        }
    }
}

private struct MainTabView: View {
    let repository: any CultureRepository
    let savedStore: SavedStore
    let fullArchiveStore: FullArchiveStore

    @State private var selectedTab: AppTab = .today
    @State private var rootTabBarHiddenDepth = 0

    var body: some View {
        ZStack {
            tabLayer(.today) {
                NavigationStack {
                    TodayView(
                        repository: repository,
                        savedStore: savedStore
                    )
                }
            }

            tabLayer(.archive) {
                NavigationStack {
                    ArchiveView(
                        repository: repository,
                        savedStore: savedStore,
                        fullArchiveStore: fullArchiveStore,
                        rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                    )
                }
            }

            tabLayer(.saved) {
                NavigationStack {
                    SavedView(
                        repository: repository,
                        savedStore: savedStore,
                        rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                    )
                }
            }
        }
        .background(HCTheme.background)
        .tint(HCTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if rootTabBarHiddenDepth == 0 {
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .humanCultureOpenToday)) { _ in
            selectedTab = .today
        }
        .animation(.easeInOut(duration: 0.18), value: rootTabBarHiddenDepth)
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
    case today
    case archive
    case saved

    var title: String {
        switch self {
        case .today: "Today"
        case .archive: "Archive"
        case .saved: "Saved"
        }
    }

    var icon: String {
        switch self {
        case .today: "calendar"
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

extension View {
    func rootTabBarHidden(_ hiddenDepth: Binding<Int>) -> some View {
        modifier(RootTabBarVisibilityModifier(hiddenDepth: hiddenDepth))
    }
}

private struct RootTabBarVisibilityModifier: ViewModifier {
    @Binding var hiddenDepth: Int
    @State private var isRegistered = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isRegistered else { return }
                hiddenDepth += 1
                isRegistered = true
            }
            .onDisappear {
                guard isRegistered else { return }
                hiddenDepth = max(hiddenDepth - 1, 0)
                isRegistered = false
            }
    }
}
