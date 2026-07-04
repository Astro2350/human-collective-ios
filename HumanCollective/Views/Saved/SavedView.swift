import SwiftUI

struct SavedView: View {
    let savedStore: SavedStore

    @State private var viewModel = SavedViewModel()
    @Binding private var selectedTab: AppTab

    init(savedStore: SavedStore, selectedTab: Binding<AppTab>) {
        self.savedStore = savedStore
        _selectedTab = selectedTab
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .task(id: savedStore.revision) {
                viewModel.load(from: savedStore)
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
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved pieces")
                            .font(.cultureTitle(34))
                            .foregroundStyle(HCTheme.ink)

                        Text("For pieces worth another look.")
                            .font(.callout)
                            .foregroundStyle(HCTheme.secondaryInk)
                    }
                    .padding(.top, 10)

                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            NavigationLink {
                                CultureDetailView(item: item, savedStore: savedStore)
                            } label: {
                                SavedItemCard(item: item)
                            }
                            .buttonStyle(.cultureCard)

                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    savedStore.unsave(item)
                                    viewModel.load(from: savedStore)
                                }
                            } label: {
                                Image(systemName: "bookmark.slash")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(HCTheme.clay)
                                    .frame(width: 42, height: 42)
                                    .background(HCTheme.surface, in: Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(HCTheme.line.opacity(0.6), lineWidth: HCTheme.hairline)
                                    }
                            }
                            .accessibilityLabel("Unsave \(item.title)")
                        }
                        .frame(width: contentWidth, alignment: .leading)
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
