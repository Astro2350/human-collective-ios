import SwiftUI

struct SavedView: View {
    let repository: any CultureRepository
    let savedStore: SavedStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var viewModel = SavedViewModel()
    @State private var selectedItem: CultureItem?

    init(repository: any CultureRepository, savedStore: SavedStore, rootTabBarHiddenDepth: Binding<Int>) {
        self.repository = repository
        self.savedStore = savedStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .task(id: savedStore.revision) {
                await viewModel.load(from: savedStore, repository: repository)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            CultureLoadingView()
        case .empty:
            savedList([])
        case .failed(let message):
            CultureErrorView(message: message) {}
        case .loaded(let items):
            savedList(items)
        }
    }

    private func savedList(_ items: [CultureItem]) -> some View {
        List {
            ScreenHeader("Saved pieces")
                .listRowInsets(.init(top: HCTheme.pagePadding, leading: HCTheme.pagePadding, bottom: 12, trailing: HCTheme.pagePadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if items.isEmpty {
                SavedEmptyRow()
                    .listRowInsets(.init(top: 10, leading: HCTheme.pagePadding, bottom: 8, trailing: HCTheme.pagePadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
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
                            unsave(item)
                        } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                    }
                }
            }

            Color.clear
                .frame(height: HCTheme.rootTabBarContentClearance)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .navigationDestination(item: $selectedItem) { item in
            CultureDetailView(item: item, savedStore: savedStore)
                .rootTabBarHidden($rootTabBarHiddenDepth)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(HCTheme.background)
        .animation(.easeInOut(duration: 0.18), value: itemSignature(for: items))
    }

    private func itemSignature(for items: [CultureItem]) -> String {
        items.reduce(into: "") { signature, item in
            if !signature.isEmpty {
                signature.append("|")
            }
            signature.append(item.id)
        }
    }

    private func unsave(_ item: CultureItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            savedStore.unsave(item)
            viewModel.display(savedStore.savedItems)
        }
    }
}

private struct SavedEmptyRow: View {
    var body: some View {
        ContentUnavailableView("No Saved Pieces", systemImage: "bookmark")
            .tint(HCTheme.clay)
            .foregroundStyle(HCTheme.secondaryInk)
            .frame(maxWidth: .infinity, minHeight: 380)
            .accessibilityElement(children: .combine)
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
                Text(item.displayTitle)
                    .font(.cultureTitle(21))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text("Creator: \(item.creatorDisplay)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(2)

                Text(item.placeDisplay.isEmpty ? item.category.title : item.placeDisplay)
                    .font(.caption)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(2)
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
