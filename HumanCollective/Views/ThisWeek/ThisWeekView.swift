import SwiftUI

struct ThisWeekView: View {
    let savedStore: SavedStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var viewModel: ThisWeekViewModel

    init(repository: any CultureRepository, savedStore: SavedStore, rootTabBarHiddenDepth: Binding<Int>) {
        self.savedStore = savedStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
        _viewModel = State(initialValue: ThisWeekViewModel(repository: repository))
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .task {
                await loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            CultureLoadingView()
        case .empty:
            CultureEmptyStateView(
                title: "This week's pack is not ready.",
                subtitle: "There is no published selection for the current week yet.",
                systemImage: "tray"
            )
        case .failed(let message):
            CultureErrorView(message: message) {
                Task { await viewModel.retry() }
            }
        case .loaded(let pack):
            packContent(pack)
        }
    }

    private func packContent(_ pack: CulturePack) -> some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: HCTheme.screenSectionSpacing) {
                    header(for: pack)

                    if let featuredItem = pack.featuredItem {
                        NavigationLink {
                            CultureDetailView(item: featuredItem, savedStore: savedStore)
                                .rootTabBarHidden($rootTabBarHiddenDepth)
                        } label: {
                            FeaturedCultureCard(item: featuredItem)
                                .frame(width: contentWidth, alignment: .leading)
                        }
                        .buttonStyle(.cultureCard)
                    }

                    if pack.items.count > 1 {
                        SectionRule(title: "Also this week")

                        ForEach(pack.items.dropFirst()) { item in
                            NavigationLink {
                                CultureDetailView(item: item, savedStore: savedStore)
                                    .rootTabBarHidden($rootTabBarHiddenDepth)
                            } label: {
                                CultureCard(item: item)
                                    .frame(width: contentWidth, alignment: .leading)
                            }
                            .buttonStyle(.cultureCard)
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, HCTheme.rootTabBarContentClearance)
            }
            .background(HCTheme.background)
            .task(id: pack.id) {
                await prefetchImages(in: pack)
            }
        }
        .background(HCTheme.background)
    }

    private func header(for pack: CulturePack) -> some View {
        ScreenHeader("This Week in\nHuman Culture") {
            WeekBadge(pack: pack)
                .padding(.top, 5)
        }
    }

    private func loadIfNeeded() async {
        if case .idle = viewModel.state {
            await viewModel.load()
        }
    }

    private func prefetchImages(in pack: CulturePack) async {
        let urls = pack.items.compactMap { item in
            CultureAsyncImage.normalizedImageURL(from: item.imageURL)
        }

        await CultureImageCache.shared.prefetch(urls)
    }
}

private struct WeekBadge: View {
    let pack: CulturePack

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(weekText)
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

    private var weekText: String {
        guard let weekNumber = pack.weekKey.split(separator: "W").last, !weekNumber.isEmpty else {
            return "This week"
        }
        return "Week \(weekNumber)"
    }
}

private struct SectionRule: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.cultureKicker())
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)

            Rectangle()
                .fill(HCTheme.line.opacity(0.65))
                .frame(height: HCTheme.hairline)

            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(HCTheme.mutedInk)
            }
        }
    }
}
