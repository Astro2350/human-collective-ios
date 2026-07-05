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
        .tint(HCTheme.ink)
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
        case .thisWeek: "book"
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

private struct AppTabIcon: View {
    let tab: AppTab

    @ViewBuilder
    var body: some View {
        switch tab {
        case .thisWeek:
            ThisWeekTabIcon()
                .frame(width: 22, height: 18)
        case .archive, .saved:
            Image(systemName: tab.icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 22, height: 18)
        }
    }
}

private struct ThisWeekTabIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let lineWidth = max(width * 0.115, 2.1)

            ZStack {
                bookPath(width: width, height: height)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                globePath(width: width, height: height)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                continentPath(width: width, height: height)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
            }
        }
        .aspectRatio(22 / 18, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func bookPath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: width * 0.07, y: height * 0.68))
            path.addLine(to: CGPoint(x: width * 0.07, y: height * 0.96))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.50, y: height * 0.91),
                control: CGPoint(x: width * 0.27, y: height * 0.82)
            )
            path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.50))
            path.move(to: CGPoint(x: width * 0.50, y: height * 0.90))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.93, y: height * 0.96),
                control: CGPoint(x: width * 0.73, y: height * 0.82)
            )
            path.addLine(to: CGPoint(x: width * 0.93, y: height * 0.68))
        }
    }

    private func globePath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.addEllipse(in: CGRect(
                x: width * 0.25,
                y: height * 0.00,
                width: width * 0.50,
                height: height * 0.50
            ))
        }
    }

    private func continentPath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: width * 0.38, y: height * 0.18))
            path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.11))
            path.addLine(to: CGPoint(x: width * 0.51, y: height * 0.21))
            path.addLine(to: CGPoint(x: width * 0.47, y: height * 0.31))
            path.addLine(to: CGPoint(x: width * 0.55, y: height * 0.36))

            path.move(to: CGPoint(x: width * 0.62, y: height * 0.13))
            path.addLine(to: CGPoint(x: width * 0.58, y: height * 0.25))
            path.addLine(to: CGPoint(x: width * 0.67, y: height * 0.30))
        }
    }
}
