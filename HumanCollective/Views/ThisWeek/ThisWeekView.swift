import SwiftUI

struct ThisWeekView: View {
    let savedStore: SavedStore

    @State private var viewModel: ThisWeekViewModel

    init(repository: any CultureRepository, savedStore: SavedStore) {
        self.savedStore = savedStore
        _viewModel = State(initialValue: ThisWeekViewModel(repository: repository))
    }

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HCTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                title: "This week's pack is empty.",
                subtitle: "Check Supabase data or use the bundled mock repository."
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
                VStack(alignment: .leading, spacing: 28) {
                    header(for: pack)

                    if let featuredItem = pack.featuredItem {
                        NavigationLink {
                            CultureDetailView(item: featuredItem, savedStore: savedStore)
                        } label: {
                            FeaturedCultureCard(item: featuredItem)
                                .frame(width: contentWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        SectionRule(title: "Also this week")

                        ForEach(Array(pack.items.dropFirst())) { item in
                            NavigationLink {
                                CultureDetailView(item: item, savedStore: savedStore)
                            } label: {
                                CultureCard(item: item)
                                    .frame(width: contentWidth, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
            }
            .background(HCTheme.background)
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
