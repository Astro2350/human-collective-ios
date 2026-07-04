import SwiftUI

struct ThisWeekView: View {
    let savedStore: SavedStore

    @State private var viewModel: ThisWeekViewModel
    @Binding private var selectedTab: AppTab

    init(repository: any CultureRepository, savedStore: SavedStore, selectedTab: Binding<AppTab>) {
        self.savedStore = savedStore
        _selectedTab = selectedTab
        _viewModel = State(initialValue: ThisWeekViewModel(repository: repository))
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .task {
                await loadIfNeeded()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selectedTab: $selectedTab)
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
                LazyVStack(alignment: .leading, spacing: 28) {
                    header(for: pack)

                    if let featuredItem = pack.featuredItem {
                        NavigationLink {
                            CultureDetailView(item: featuredItem, savedStore: savedStore)
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
                .padding(.bottom, 12)
            }
            .background(HCTheme.background)
            .task(id: pack.id) {
                await prefetchImages(in: pack)
            }
        }
        .background(HCTheme.background)
    }

    private func header(for pack: CulturePack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("This Week in\nHuman Collective")
                    .font(.cultureTitle(32))
                    .foregroundStyle(HCTheme.ink)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)

                WeekBadge(pack: pack)
                    .padding(.top, 5)
            }

            Rectangle()
                .fill(HCTheme.line.opacity(0.75))
                .frame(height: HCTheme.hairline)
                .padding(.top, 2)
        }
        .padding(.top, 18)
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
