import SwiftUI

struct SavedView: View {
    let savedStore: SavedStore

    @State private var viewModel = SavedViewModel()

    var body: some View {
        content
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(HCTheme.background, for: .navigationBar)
            .background(HCTheme.background)
            .task(id: savedStore.revision) {
                viewModel.load(from: savedStore)
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
                subtitle: "Bookmark anything you want to revisit."
            )
        case .failed(let message):
            CultureErrorView(message: message) {}
        case .loaded(let items):
            savedList(items)
        }
    }

    private func savedList(_ items: [CultureItem]) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        NavigationLink {
                            CultureDetailView(item: item, savedStore: savedStore)
                        } label: {
                            SavedItemCard(item: item)
                        }
                        .buttonStyle(.plain)

                        Button {
                            savedStore.unsave(item)
                            viewModel.load(from: savedStore)
                        } label: {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(HCTheme.clay)
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("Unsave \(item.title)")
                    }
                }
            }
            .padding(HCTheme.pagePadding)
        }
        .background(HCTheme.background)
    }
}

private struct SavedItemCard: View {
    let item: CultureItem

    var body: some View {
        HStack(spacing: 12) {
            CultureAsyncImage(imageURL: item.imageURL, aspectRatio: 1.0, cornerRadius: 6)
                .frame(width: 92)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.cultureTitle(20))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text(item.placeDisplay)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(2)

                CategoryChip(category: item.category)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: 1)
        }
    }
}
