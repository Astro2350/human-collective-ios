import SwiftUI

struct SavedView: View {
    let repository: any CultureRepository
    let savedStore: SavedStore

    @State private var viewModel = SavedViewModel()
    @State private var selectedItem: CultureItem?
    @Binding private var selectedTab: AppTab

    init(repository: any CultureRepository, savedStore: SavedStore, selectedTab: Binding<AppTab>) {
        self.repository = repository
        self.savedStore = savedStore
        _selectedTab = selectedTab
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .task(id: savedStore.revision) {
                await viewModel.load(from: savedStore, repository: repository)
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
                title: "Saved pieces will live here.",
                subtitle: "Use the bookmark on any piece you want to revisit.",
                systemImage: "bookmark"
            )
        case .failed(let message):
            CultureErrorView(message: message) {}
        case .loaded(let items):
            savedList(items)
        }
    }

    private func savedList(_ items: [CultureItem]) -> some View {
        List {
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved pieces")
                    .font(.cultureTitle(34))
                    .foregroundStyle(HCTheme.ink)
            }
            .padding(.top, 10)
            .listRowInsets(.init(top: 0, leading: HCTheme.pagePadding, bottom: 10, trailing: HCTheme.pagePadding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    SavedItemCard(item: item)
                }
                .buttonStyle(.plain)
                .listRowInsets(.init(top: 8, leading: HCTheme.pagePadding, bottom: 8, trailing: HCTheme.pagePadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            savedStore.unsave(item)
                        }
                    } label: {
                        Label("Unsave", systemImage: "bookmark.slash")
                    }
                }
            }
        }
        .navigationDestination(item: $selectedItem) { item in
            CultureDetailView(item: item, savedStore: savedStore)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(HCTheme.background)
    }
}

private struct SavedItemCard: View {
    let item: CultureItem

    var body: some View {
        HStack(spacing: 12) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 1.0,
                cornerRadius: 6,
                accessibilityLabel: item.title
            )
                .frame(width: 96)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.cultureTitle(21))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text(item.placeDisplay)
                    .font(.caption)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(2)

                CategoryChip(category: item.category)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
        .shadow(color: .black.opacity(0.03), radius: 12, x: 0, y: 7)
    }
}
