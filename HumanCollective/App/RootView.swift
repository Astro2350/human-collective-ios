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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: AppTab = .thisWeek

    var body: some View {
        ZStack {
            tabLayer(.thisWeek) {
                NavigationStack {
                    ThisWeekView(repository: repository, savedStore: savedStore, selectedTab: $selectedTab)
                }
            }

            tabLayer(.archive) {
                NavigationStack {
                    ArchiveView(repository: repository, savedStore: savedStore, selectedTab: $selectedTab)
                }
            }

            tabLayer(.saved) {
                NavigationStack {
                    SavedView(repository: repository, savedStore: savedStore, selectedTab: $selectedTab)
                }
            }
        }
        .background(HCTheme.background)
        .tint(.black)
        .animation(tabTransitionAnimation, value: selectedTab)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private var tabTransitionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.24)
    }

    private func tabLayer<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = selectedTab == tab

        return content()
            .opacity(isSelected ? 1 : 0)
            .scaleEffect(isSelected ? 1 : 0.985)
            .offset(y: isSelected ? 0 : 8)
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
        case .thisWeek: "sun.max"
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
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))

                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background {
                        if tab == selectedTab {
                            Capsule()
                                .fill(Color.black.opacity(0.06))
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
        .background(.white)
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

        withAnimation(tabSelectionAnimation) {
            selectedTab = tab
        }
    }
}
