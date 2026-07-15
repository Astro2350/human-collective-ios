import SwiftUI

struct CultureDetailView: View {
    @Environment(CultureCatalogStore.self) private var catalogStore

    private let savedStore: SavedStore
    @State private var viewModel: CultureDetailViewModel

    init(item: CultureItem, savedStore: SavedStore) {
        self.savedStore = savedStore
        _viewModel = State(initialValue: CultureDetailViewModel(item: item, savedStore: savedStore))
    }

    var body: some View {
        let item = viewModel.item

        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CultureItemArticleView(
                        item: item,
                        isSaved: viewModel.isSaved,
                        showsSaveAction: false,
                        contentBottomPadding: relatedItems.isEmpty ? 42 : 22,
                        onToggleSaved: viewModel.toggleSaved
                    )

                    if !relatedItems.isEmpty {
                        ConnectedPiecesSection(items: relatedItems, savedStore: savedStore)
                            .padding(.horizontal, HCTheme.pagePadding)
                            .padding(.bottom, 42)
                    }
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
        }
        .background(HCTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.toggleSaved()
                    }
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave" : "Save")
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.isSaved)
    }

    private var relatedItems: [CultureItem] {
        catalogStore.relatedItems(to: viewModel.item)
    }
}

private struct ConnectedPiecesSection: View {
    let items: [CultureItem]
    let savedStore: SavedStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected pieces")
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)

            ForEach(items) { item in
                NavigationLink {
                    CultureDetailView(item: item, savedStore: savedStore)
                } label: {
                    HStack(spacing: 12) {
                        CultureAsyncImage(
                            imageURL: item.imageURL,
                            aspectRatio: 1,
                            cornerRadius: 5,
                            accessibilityLabel: item.title
                        )
                        .frame(width: 64)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayTitle)
                                .font(.headline)
                                .foregroundStyle(HCTheme.ink)
                                .lineLimit(2)

                            Text(item.creatorDisplay)
                                .font(.caption)
                                .foregroundStyle(HCTheme.mutedInk)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HCTheme.mutedInk)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)

                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
    }
}
