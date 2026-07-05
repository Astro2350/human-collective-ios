import SwiftUI

struct ArchiveView: View {
    private let freeArchivePackLimit = 2

    let savedStore: SavedStore
    let fullArchiveStore: FullArchiveStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var isShowingFullArchivePaywall = false
    @State private var viewModel: ArchiveViewModel

    init(
        repository: any CultureRepository,
        savedStore: SavedStore,
        fullArchiveStore: FullArchiveStore,
        rootTabBarHiddenDepth: Binding<Int>
    ) {
        self.savedStore = savedStore
        self.fullArchiveStore = fullArchiveStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
        _viewModel = State(initialValue: ArchiveViewModel(repository: repository))
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
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
            archiveList([])
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
            let visiblePacks = visibleArchivePacks(from: packs)
            let lockedPackCount = max(packs.count - visiblePacks.count, 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader("Archive")

                        FullArchiveCard(
                            isUnlocked: fullArchiveStore.hasFullArchiveAccess,
                            lockedPackCount: lockedPackCount
                        ) {
                            if !fullArchiveStore.hasFullArchiveAccess {
                                isShowingFullArchivePaywall = true
                            }
                        }
                            .frame(width: contentWidth, alignment: .leading)
                    }

                    if visiblePacks.isEmpty {
                        ArchiveInlineEmptyState()
                            .frame(width: contentWidth, alignment: .leading)
                    } else {
                        if let featuredPack = visiblePacks.first {
                            archivePackLink(featuredPack) {
                                ArchiveFeaturedWeekCard(pack: featuredPack)
                                    .frame(width: contentWidth, alignment: .leading)
                            }
                        }

                        let shelves = ArchiveBrowseShelf.makeShelves(from: visiblePacks)
                        if !shelves.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                ArchiveSectionHeader(title: "Browse")

                                ForEach(shelves) { shelf in
                                    ArchiveBrowseShelfView(
                                        shelf: shelf,
                                        savedStore: savedStore,
                                        rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                                    )
                                }
                            }
                            .frame(width: contentWidth, alignment: .leading)
                        }

                        let earlierPacks = Array(visiblePacks.dropFirst())
                        if !earlierPacks.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                ArchiveSectionHeader(title: "Earlier weeks")

                                ForEach(earlierPacks) { pack in
                                    archivePackLink(pack) {
                                        ArchiveWeekCard(pack: pack)
                                            .frame(width: contentWidth, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, HCTheme.rootTabBarContentClearance)
            }
            .background(HCTheme.background)
            .sheet(isPresented: $isShowingFullArchivePaywall) {
                FullArchivePaywallView(fullArchiveStore: fullArchiveStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .background(HCTheme.background)
    }

    private func visibleArchivePacks(from packs: [CulturePack]) -> [CulturePack] {
        if fullArchiveStore.hasFullArchiveAccess {
            return packs
        }

        return Array(packs.prefix(freeArchivePackLimit))
    }

    private func loadIfNeeded() async {
        if case .idle = viewModel.state {
            await viewModel.load()
        }
    }

    private func archivePackLink<Label: View>(
        _ pack: CulturePack,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            ArchivePackView(
                pack: pack,
                savedStore: savedStore,
                rootTabBarHiddenDepth: $rootTabBarHiddenDepth
            )
            .rootTabBarHidden($rootTabBarHiddenDepth)
        } label: {
            label()
        }
        .buttonStyle(.cultureCard)
    }
}

private struct FullArchiveCard: View {
    let isUnlocked: Bool
    let lockedPackCount: Int
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: action) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isUnlocked ? "checkmark" : "lock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HCTheme.clay.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .background(HCTheme.editorGold.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isUnlocked ? "Full Archive Unlocked" : "Full Archive")
                            .font(.cultureKicker())
                            .textCase(.uppercase)
                            .foregroundStyle(HCTheme.clay.opacity(0.92))

                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(HCTheme.secondaryInk)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if !isUnlocked {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HCTheme.mutedInk.opacity(0.72))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isUnlocked)

            Rectangle()
                .fill(HCTheme.line.opacity(0.75))
                .frame(height: HCTheme.hairline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var subtitle: String {
        if isUnlocked {
            return "Every archived week is available."
        }

        if lockedPackCount > 0 {
            return "Unlock \(lockedPackCount) more weekly \(lockedPackCount == 1 ? "archive" : "archives"), maps, timelines, and creators."
        }

        return "Explore every past piece, map, timeline, and creator in one complete archive."
    }

    private var accessibilityLabel: String {
        isUnlocked ? "Full Archive unlocked. \(subtitle)" : "Full Archive. \(subtitle)"
    }
}

private struct FullArchivePaywallView: View {
    let fullArchiveStore: FullArchiveStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Text("Full Archive")
                        .font(.cultureTitle(38))
                        .foregroundStyle(HCTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HCTheme.ink)
                            .frame(width: 34, height: 34)
                            .background(HCTheme.surfaceRaised, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Text("Unlock every past piece in one clean archive.")
                    .font(.title3)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                PaywallBenefitRow(text: "All past daily pieces and weekly collections")
                PaywallBenefitRow(text: "Every map, timeline, creator, and source")
                PaywallBenefitRow(text: "One-time unlock with restore anytime")
            }

            if let message = fullArchiveStore.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(HCTheme.clay)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    Task { await fullArchiveStore.purchase() }
                } label: {
                    HStack {
                        if isBusy {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(fullArchiveStore.purchaseButtonTitle)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(HCTheme.blueStone, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isBusy || fullArchiveStore.hasFullArchiveAccess)

                Button {
                    Task { await fullArchiveStore.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HCTheme.secondaryInk)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        }
        .padding(HCTheme.pagePadding)
        .background(HCTheme.background)
        .task {
            if !fullArchiveStore.hasFullArchiveAccess {
                await fullArchiveStore.loadProducts()
            }
        }
        .onChange(of: fullArchiveStore.hasFullArchiveAccess) { _, isUnlocked in
            if isUnlocked {
                dismiss()
            }
        }
    }

    private var isBusy: Bool {
        switch fullArchiveStore.purchaseState {
        case .loading, .purchasing, .restoring:
            return true
        case .idle, .unlocked, .unavailable, .failed:
            return false
        }
    }
}

private struct PaywallBenefitRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HCTheme.clay)
                .frame(width: 22, height: 22)
                .background(HCTheme.editorGold.opacity(0.14), in: Circle())

            Text(text)
                .font(.callout)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ArchiveInlineEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(HCTheme.mutedInk)
                .frame(width: 42, height: 42)
                .background(HCTheme.surfaceRaised, in: Circle())
                .overlay {
                    Circle()
                        .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("No archived weeks yet.")
                    .font(.cultureTitle(25))
                    .foregroundStyle(HCTheme.ink)

                Text("The first weekly archive appears after this week closes.")
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct ArchiveSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.cultureKicker())
            .textCase(.uppercase)
            .foregroundStyle(HCTheme.clay)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ArchiveFeaturedWeekCard: View {
    let pack: CulturePack

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item = pack.featuredItem {
                CultureAsyncImage(
                    imageURL: item.imageURL,
                    aspectRatio: 1.06,
                    cornerRadius: 0,
                    accessibilityLabel: item.title
                )
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(CultureFormatters.shortWeek(startDate: pack.startDate, endDate: pack.endDate))
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.clay)

                Text(pack.title)
                    .font(.cultureTitle(31))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pack.subtitle)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !pack.items.isEmpty {
                    ArchiveTinyImageStrip(items: Array(pack.items.dropFirst().prefix(4)))
                        .padding(.top, 5)
                }
            }
            .padding(15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct ArchiveTinyImageStrip: View {
    let items: [CultureItem]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(items) { item in
                CultureAsyncImage(
                    imageURL: item.imageURL,
                    aspectRatio: 1.0,
                    cornerRadius: 5,
                    accessibilityLabel: item.title
                )
                .frame(width: 46)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ArchiveWeekCard: View {
    let pack: CulturePack

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let item = pack.featuredItem {
                CultureAsyncImage(
                    imageURL: item.imageURL,
                    aspectRatio: 1.0,
                    cornerRadius: 6,
                    accessibilityLabel: item.title
                )
                .frame(width: 86)
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
                    .font(.footnote)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
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
        .shadow(color: .black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

private struct ArchiveBrowseShelf: Identifiable {
    let id: String
    let title: String
    let items: [CultureItem]

    static func makeShelves(from packs: [CulturePack]) -> [ArchiveBrowseShelf] {
        let items = packs.flatMap(\.items)
        let definitions: [(String, String, (CultureItem) -> Bool)] = [
            ("creatures", "Creatures", { item in
                let text = searchableText(for: item)
                return text.contains("dog") ||
                    text.contains("cat") ||
                    text.contains("hippo") ||
                    text.contains("horse") ||
                    text.contains("octopus") ||
                    text.contains("turtle") ||
                    text.contains("bull") ||
                    text.contains("rhinoceros")
            }),
            ("faces", "Faces and masks", { item in
                item.category == .mask || item.title.localizedCaseInsensitiveContains("mask") || searchableText(for: item).contains("portrait")
            }),
            ("maps", "Maps and knowledge", { item in
                item.category == .map || item.category == .manuscript || item.category == .tool
            }),
            ("small", "Small wonders", { item in
                let text = searchableText(for: item)
                return text.contains("netsuke") || text.contains("chessmen") || text.contains("vessel")
            })
        ]

        return definitions.compactMap { id, title, matches in
            let sectionItems = uniqueItems(items.filter(matches)).prefix(8)
            guard !sectionItems.isEmpty else { return nil }
            return ArchiveBrowseShelf(id: id, title: title, items: Array(sectionItems))
        }
    }

    private static func uniqueItems(_ items: [CultureItem]) -> [CultureItem] {
        var seen = Set<String>()
        return items.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
    }

    private static func searchableText(for item: CultureItem) -> String {
        [
            item.title,
            item.hook,
            item.culture,
            item.region,
            item.country
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }
}

private struct ArchiveBrowseShelfView: View {
    let shelf: ArchiveBrowseShelf
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shelf.title)
                .font(.cultureTitle(22))
                .foregroundStyle(HCTheme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(shelf.items) { item in
                        NavigationLink {
                            CultureDetailView(item: item, savedStore: savedStore)
                                .rootTabBarHidden($rootTabBarHiddenDepth)
                        } label: {
                            ArchiveBrowseItemCard(item: item)
                        }
                        .buttonStyle(.cultureCard)
                    }
                }
                .padding(.trailing, HCTheme.pagePadding)
            }
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ArchiveBrowseItemCard: View {
    let item: CultureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 0.82,
                cornerRadius: 6,
                accessibilityLabel: item.title
            )

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HCTheme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.creatorDisplay)
                .font(.caption2.weight(.medium))
                .foregroundStyle(HCTheme.mutedInk)
                .lineLimit(1)
        }
        .frame(width: 124, alignment: .leading)
    }
}
