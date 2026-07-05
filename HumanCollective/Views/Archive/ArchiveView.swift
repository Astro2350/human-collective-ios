import SwiftUI

struct ArchiveView: View {
    let savedStore: SavedStore

    @State private var viewModel: ArchiveViewModel
    @Binding private var selectedTab: AppTab

    init(repository: any CultureRepository, savedStore: SavedStore, selectedTab: Binding<AppTab>) {
        self.savedStore = savedStore
        _selectedTab = selectedTab
        _viewModel = State(initialValue: ArchiveViewModel(repository: repository))
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
                title: "No archived packs yet.",
                subtitle: "Earlier weekly selections will appear here after they close.",
                systemImage: "books.vertical"
            )
        case .failed(let message):
            CultureErrorView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded(let packs):
            archiveList(packs)
        }
    }

    private func archiveList(_ packs: [CulturePack]) -> some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Archive")
                            .font(.cultureTitle(34))
                            .foregroundStyle(HCTheme.ink)
                    }
                    .padding(.top, 10)

                    ForEach(packs) { pack in
                        NavigationLink {
                            ArchivePackView(pack: pack, savedStore: savedStore)
                        } label: {
                            ArchiveWeekCard(pack: pack)
                                .frame(width: contentWidth, alignment: .leading)
                        }
                        .buttonStyle(.cultureCard)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, 12)
            }
            .background(HCTheme.background)
        }
        .background(HCTheme.background)
    }

    private func loadIfNeeded() async {
        if case .idle = viewModel.state {
            await viewModel.load()
        }
    }
}

private struct ArchiveWeekCard: View {
    let pack: CulturePack

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(Array(pack.items.prefix(3))) { item in
                    CultureAsyncImage(
                        imageURL: item.imageURL,
                        aspectRatio: 1.0,
                        cornerRadius: 6,
                        accessibilityLabel: item.title
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(CultureFormatters.shortWeek(startDate: pack.startDate, endDate: pack.endDate))
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.clay)

                Text(pack.title)
                    .font(.cultureTitle(26))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pack.subtitle)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}
