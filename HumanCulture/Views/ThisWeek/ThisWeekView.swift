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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(for: pack)

                if let featuredItem = pack.featuredItem {
                    NavigationLink {
                        CultureDetailView(item: featuredItem, savedStore: savedStore)
                    } label: {
                        FeaturedCultureCard(item: featuredItem)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly Pack")
                        .font(.headline)
                        .foregroundStyle(HCTheme.secondaryInk)

                    ForEach(Array(pack.items.dropFirst())) { item in
                        NavigationLink {
                            CultureDetailView(item: item, savedStore: savedStore)
                        } label: {
                            CultureCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(HCTheme.pagePadding)
        }
        .background(HCTheme.background)
    }

    private func header(for pack: CulturePack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week in Human Culture")
                .font(.cultureTitle(36))
                .foregroundStyle(HCTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(CultureFormatters.weekRange(startDate: pack.startDate, endDate: pack.endDate))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(HCTheme.secondaryInk)

            Text(pack.subtitle)
                .font(.callout)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(3)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private func loadIfNeeded() async {
        if case .idle = viewModel.state {
            await viewModel.load()
        }
    }
}

