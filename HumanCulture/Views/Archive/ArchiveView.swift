import SwiftUI

struct ArchiveView: View {
    let savedStore: SavedStore

    @State private var viewModel: ArchiveViewModel

    init(repository: any CultureRepository, savedStore: SavedStore) {
        self.savedStore = savedStore
        _viewModel = State(initialValue: ArchiveViewModel(repository: repository))
    }

    var body: some View {
        content
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.large)
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
                title: "No archived packs yet.",
                subtitle: "Previous weeks will appear here."
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Previous weekly packs")
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .padding(.top, 8)

                ForEach(packs) { pack in
                    NavigationLink {
                        ArchivePackView(pack: pack, savedStore: savedStore)
                    } label: {
                        ArchiveWeekCard(pack: pack)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HCTheme.pagePadding)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Array(pack.items.prefix(3))) { item in
                    CultureAsyncImage(imageURL: item.imageURL, aspectRatio: 1.0, cornerRadius: 6)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(CultureFormatters.shortWeek(startDate: pack.startDate, endDate: pack.endDate))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.clay)

                Text(pack.title)
                    .font(.cultureTitle(24))
                    .foregroundStyle(HCTheme.ink)

                Text(pack.subtitle)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: 1)
        }
    }
}

