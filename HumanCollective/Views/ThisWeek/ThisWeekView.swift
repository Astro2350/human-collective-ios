import SwiftUI

struct TodayView: View {
    let savedStore: SavedStore
    let supportStore: SupportStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var viewModel: ThisWeekViewModel
    @State private var selectedSetup: TodaySetupDestination?

    init(
        repository: any CultureRepository,
        savedStore: SavedStore,
        supportStore: SupportStore,
        rootTabBarHiddenDepth: Binding<Int>
    ) {
        self.savedStore = savedStore
        self.supportStore = supportStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
        _viewModel = State(initialValue: ThisWeekViewModel(repository: repository))
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .overlay(alignment: .bottomTrailing) {
                TodaySettingsMenu { destination in
                    selectedSetup = destination
                }
                .padding(.trailing, HCTheme.pagePadding)
                .padding(.bottom, 74)
            }
            .task {
                await loadIfNeeded()
            }
            .navigationDestination(item: $selectedSetup) { destination in
                Group {
                    switch destination {
                    case .widgets:
                        WidgetSetupView()
                    case .wallpaper:
                        WallpaperSetupView()
                    case .support:
                        SupportHumanCollectiveView(supportStore: supportStore)
                    }
                }
                .rootTabBarHidden($rootTabBarHiddenDepth)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            CultureLoadingView()
        case .empty:
            CultureEmptyStateView(
                title: "Today's piece is not ready.",
                subtitle: "The daily selection will appear here when it is published.",
                systemImage: "calendar"
            )
        case .failed(let message):
            CultureErrorView(message: message) {
                Task { await viewModel.retry() }
            }
        case .loaded(let pack):
            todayContent(pack)
        }
    }

    @ViewBuilder
    private func todayContent(_ pack: CulturePack) -> some View {
        if let selection = pack.dailySelection() {
            dailyPieceContent(pack: pack, selection: selection)
        } else {
            CultureEmptyStateView(
                title: "Today's piece is not ready.",
                subtitle: "The daily selection will appear here when it is published.",
                systemImage: "calendar"
            )
        }
    }

    private func dailyPieceContent(pack: CulturePack, selection: CultureDailySelection) -> some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 1)
            let imageMaxHeight = min(max(proxy.size.height * 0.52, 320), 430)
            let imageMinimumAspectRatio = contentWidth / imageMaxHeight

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(for: pack, selection: selection)
                        .padding(.horizontal, HCTheme.pagePadding)
                        .padding(.top, HCTheme.pagePadding)

                    CultureItemArticleView(
                        item: selection.item,
                        isSaved: savedStore.isSaved(selection.item),
                        showsSaveAction: true,
                        imageHorizontalPadding: HCTheme.pagePadding,
                        imageCornerRadius: HCTheme.cardRadius,
                        imageUsesNaturalAspectRatio: true,
                        imageMinimumAspectRatio: imageMinimumAspectRatio,
                        contentBottomPadding: 18
                    ) {
                        savedStore.toggle(selection.item)
                    }
                }
                .frame(width: proxy.size.width, alignment: .leading)
                .padding(.bottom, 76)
            }
            .background(HCTheme.background)
            .task(id: pack.id) {
                await prefetchImages(for: selection.item)
            }
        }
        .background(HCTheme.background)
        .sensoryFeedback(.selection, trigger: savedStore.revision)
    }

    private func header(for pack: CulturePack, selection: CultureDailySelection) -> some View {
        ScreenHeader("Today") {
            DayBadge(pack: pack, selection: selection)
                .padding(.top, 5)
        }
    }

    private func loadIfNeeded() async {
        if case .idle = viewModel.state {
            await viewModel.load()
        }
    }

    private func prefetchImages(for item: CultureItem) async {
        let urls = [CultureAsyncImage.normalizedImageURL(from: item.imageURL)].compactMap { $0 }

        await CultureImageCache.shared.prefetch(urls)
    }
}

private enum TodaySetupDestination: String, Identifiable {
    case widgets
    case wallpaper
    case support

    var id: String { rawValue }
}

private struct TodaySettingsMenu: View {
    let selectSetup: (TodaySetupDestination) -> Void

    var body: some View {
        Menu {
            Button {
                selectSetup(.widgets)
            } label: {
                Label("Widgets", systemImage: "square.grid.2x2")
            }

            Button {
                selectSetup(.wallpaper)
            } label: {
                Label("Wallpaper", systemImage: "photo.on.rectangle.angled")
            }

            Button {
                selectSetup(.support)
            } label: {
                Label("Support The Human Collective", systemImage: "heart")
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(HCTheme.ink)
                .frame(width: 54, height: 54)
                .background(HCTheme.surface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(HCTheme.line.opacity(0.7), lineWidth: HCTheme.hairline)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
        }
        .accessibilityLabel("Artifact settings")
        .accessibilityHint("Opens widget, wallpaper, and support options")
    }
}

private struct DayBadge: View {
    let pack: CulturePack
    let selection: CultureDailySelection

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("Day \(selection.dayNumber) of \(selection.totalDays)")
                .font(.cultureKicker(10))
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)

            Text(CultureFormatters.shortWeek(startDate: pack.startDate, endDate: pack.endDate))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HCTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .multilineTextAlignment(.trailing)
        .frame(width: 104, alignment: .trailing)
    }
}
