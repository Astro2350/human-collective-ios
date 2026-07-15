import SwiftUI

struct ProfileView: View {
    let repository: any CultureRepository
    let communityRepository: any CommunityRepository
    let savedStore: SavedStore
    let profileStore: ProfileStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var savedViewModel = SavedViewModel()
    @State private var selectedItem: CultureItem?

    private var savedItems: [CultureItem] {
        switch savedViewModel.state {
        case .loaded(let items): items
        case .empty: []
        case .idle, .loading, .failed: savedStore.savedItems
        }
    }

    init(
        repository: any CultureRepository,
        communityRepository: any CommunityRepository,
        savedStore: SavedStore,
        profileStore: ProfileStore,
        rootTabBarHiddenDepth: Binding<Int>
    ) {
        self.repository = repository
        self.communityRepository = communityRepository
        self.savedStore = savedStore
        self.profileStore = profileStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ScreenHeader("Profile")

                    SubmissionSection(receipts: profileStore.submissions)

                    SavedSection(items: savedItems, onSelect: select, onUnsave: unsave)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, HCTheme.rootTabBarContentClearance)
            }
            .refreshable {
                await refreshProfile()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(HCTheme.background)
        .navigationDestination(item: $selectedItem) { item in
            CultureDetailView(item: item, savedStore: savedStore)
                .rootTabBarHidden($rootTabBarHiddenDepth)
        }
        .task(id: savedStore.revision) {
            await savedViewModel.load(from: savedStore, repository: repository)
        }
        .task(id: profileStore.submissions.map(\.id)) {
            await refreshSubmissionStatuses()
        }
    }

    private func select(_ item: CultureItem) {
        selectedItem = item
    }

    private func unsave(_ item: CultureItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            savedStore.unsave(item)
            savedViewModel.display(savedStore.savedItems)
        }
    }

    private func refreshProfile() async {
        await savedViewModel.load(from: savedStore, repository: repository)
        await refreshSubmissionStatuses()
    }

    private func refreshSubmissionStatuses() async {
        let ids = profileStore.submissions.map(\.id)
        guard !ids.isEmpty,
              let statuses = try? await communityRepository.fetchSubmissionStatuses(ids: ids) else {
            return
        }
        profileStore.mergeSubmissionStatuses(statuses)
    }
}

private struct SubmissionSection: View {
    let receipts: [ProfileSubmissionReceipt]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Submissions")
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)

            if receipts.isEmpty {
                Text("Pieces you submit will appear here with their review status.")
                    .font(.callout)
                    .foregroundStyle(HCTheme.mutedInk)
            } else {
                ForEach(receipts) { receipt in
                    SubmissionReceiptRow(receipt: receipt)
                    if receipt.id != receipts.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct SubmissionReceiptRow: View {
    let receipt: ProfileSubmissionReceipt

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: receipt.status.systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.title)
                    .font(.headline)
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text("\(receipt.creatorName) · \(receipt.category.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(1)

                Text("\(receipt.status.title) · \(receipt.submittedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(HCTheme.mutedInk)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch receipt.status {
        case .pending: HCTheme.editorGold
        case .approved: HCTheme.moss
        case .rejected, .removed: HCTheme.mutedInk
        }
    }
}

private struct SavedSection: View {
    let items: [CultureItem]
    let onSelect: (CultureItem) -> Void
    let onUnsave: (CultureItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved")
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)

            if items.isEmpty {
                Text("Pieces you save will appear here.")
                    .font(.callout)
                    .foregroundStyle(HCTheme.mutedInk)
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        SavedItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            onUnsave(item)
                        } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                    }
                }
            }
        }
    }
}

struct SavedItemCard: View {
    let item: CultureItem

    var body: some View {
        HStack(spacing: 12) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 1,
                cornerRadius: 6,
                accessibilityLabel: item.title
            )
            .frame(width: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.cultureTitle(20))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text(item.creatorDisplay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(2)

                Text(item.placeDisplay.isEmpty ? item.category.title : item.placeDisplay)
                    .font(.caption)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
