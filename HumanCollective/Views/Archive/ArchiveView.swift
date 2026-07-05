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

                        if !fullArchiveStore.hasFullArchiveAccess {
                            FullArchiveCard(
                                lockedPackCount: lockedPackCount
                            ) {
                                isShowingFullArchivePaywall = true
                            }
                            .frame(width: contentWidth, alignment: .leading)
                        }
                    }
                    .zIndex(1)

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

                        let earlierPacks = Array(visiblePacks.dropFirst())
                        if !earlierPacks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                ArchiveSectionHeader(title: "Past weeks")

                                ForEach(earlierPacks) { pack in
                                    archivePackLink(pack) {
                                        ArchiveWeekCard(pack: pack)
                                            .frame(width: contentWidth, alignment: .leading)
                                    }
                                }
                            }
                            .frame(width: contentWidth, alignment: .leading)
                        }

                        let shelves = ArchiveBrowseShelf.makeShelves(from: visiblePacks)
                        if !shelves.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                ArchiveSectionHeader(title: "Explore by theme")

                                ArchiveThemeGridView(
                                    shelves: shelves,
                                    savedStore: savedStore,
                                    rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                                )
                            }
                            .frame(width: contentWidth, alignment: .leading)
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
    let lockedPackCount: Int
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HCTheme.clay.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(HCTheme.editorGold.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Archive")
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HCTheme.mutedInk.opacity(0.72))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)

            Rectangle()
                .fill(HCTheme.line.opacity(0.75))
                .frame(height: HCTheme.hairline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        if lockedPackCount > 0 {
            return "Unlock \(lockedPackCount) more weekly \(lockedPackCount == 1 ? "archive" : "archives"), maps, timelines, and creators."
        }

        return "Explore every past piece, map, timeline, and creator in one complete archive."
    }

    private var accessibilityLabel: String {
        "Full Archive. \(subtitle)"
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
    let subtitle: String
    let items: [CultureItem]

    static func makeShelves(from packs: [CulturePack]) -> [ArchiveBrowseShelf] {
        let items = packs.flatMap(\.items)
        let definitions: [(String, String, String, (CultureItem) -> Bool)] = [
            ("creatures", "Creatures", "Animals, vessels, and tiny carved companions", { item in
                let text = searchableText(for: item)
                return text.contains("dog") ||
                    text.contains("cat") ||
                    text.contains("hippo") ||
                    text.contains("horse") ||
                    text.contains("octopus") ||
                    text.contains("turtle") ||
                    text.contains("bull") ||
                    text.contains("frog") ||
                    text.contains("fish") ||
                    text.contains("owl") ||
                    text.contains("rabbit") ||
                    text.contains("monkey") ||
                    text.contains("hedgehog") ||
                    text.contains("rhinoceros")
            }),
            ("faces", "Faces and masks", "Portraits, masks, and figures with presence", { item in
                let text = searchableText(for: item)
                return item.category == .mask ||
                    item.title.localizedCaseInsensitiveContains("mask") ||
                    text.contains("portrait") ||
                    text.contains("face") ||
                    text.contains("head") ||
                    text.contains("figure") ||
                    text.contains("statuette")
            }),
            ("knowledge", "Maps and knowledge", "Books, tools, diagrams, and ways of reading the world", { item in
                let text = searchableText(for: item)
                return item.category == .map ||
                    item.category == .manuscript ||
                    item.category == .tool ||
                    text.contains("map") ||
                    text.contains("book") ||
                    text.contains("astrolabe") ||
                    text.contains("stone") ||
                    text.contains("law")
            }),
            ("small", "Small wonders", "Netsuke, jewelry, amulets, and compact objects", { item in
                let text = searchableText(for: item)
                return text.contains("netsuke") ||
                    text.contains("chessmen") ||
                    text.contains("amulet") ||
                    text.contains("ring") ||
                    text.contains("perfume") ||
                    text.contains("small") ||
                    text.contains("tiny")
            })
        ]

        return definitions.compactMap { id, title, subtitle, matches in
            let sectionItems = uniqueItems(items.filter(matches)).prefix(12)
            guard !sectionItems.isEmpty else { return nil }
            return ArchiveBrowseShelf(id: id, title: title, subtitle: subtitle, items: Array(sectionItems))
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

private struct ArchiveThemeGridView: View {
    let shelves: [ArchiveBrowseShelf]
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(shelves) { shelf in
                NavigationLink {
                    ArchiveThemeView(
                        shelf: shelf,
                        savedStore: savedStore,
                        rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                    )
                    .rootTabBarHidden($rootTabBarHiddenDepth)
                } label: {
                    ArchiveThemeCard(shelf: shelf)
                }
                .buttonStyle(.cultureCard)
            }
        }
    }
}

private struct ArchiveThemeCard: View {
    let shelf: ArchiveBrowseShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArchiveThemeImageStrip(items: Array(shelf.items.prefix(3)))

            VStack(alignment: .leading, spacing: 4) {
                Text(shelf.title)
                    .font(.cultureTitle(20))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(shelf.items.count) pieces")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.clay)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
        .shadow(color: .black.opacity(0.025), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shelf.title), \(shelf.items.count) pieces")
    }
}

private struct ArchiveThemeImageStrip: View {
    let items: [CultureItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                CultureAsyncImage(
                    imageURL: item.imageURL,
                    aspectRatio: 1.0,
                    cornerRadius: 5,
                    accessibilityLabel: item.title
                )
            }
        }
        .frame(height: 44)
    }
}

private struct ArchiveThemeView: View {
    let shelf: ArchiveBrowseShelf
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Archive")
                            .font(.cultureKicker())
                            .textCase(.uppercase)
                            .foregroundStyle(HCTheme.clay)

                        Text(shelf.title)
                            .font(.cultureTitle(38))
                            .foregroundStyle(HCTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(shelf.subtitle)
                            .font(.callout)
                            .foregroundStyle(HCTheme.secondaryInk)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, HCTheme.screenTopPadding)

                    ForEach(shelf.items) { item in
                        NavigationLink {
                            CultureDetailView(item: item, savedStore: savedStore)
                                .rootTabBarHidden($rootTabBarHiddenDepth)
                        } label: {
                            ArchiveThemeItemRow(item: item)
                                .frame(width: contentWidth, alignment: .leading)
                        }
                        .buttonStyle(.cultureCard)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, HCTheme.screenBottomPadding)
            }
            .background(HCTheme.background)
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(HCTheme.background)
    }
}

private struct ArchiveThemeItemRow: View {
    let item: CultureItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 1.0,
                cornerRadius: 6,
                accessibilityLabel: item.title
            )
            .frame(width: 78)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.creatorDisplay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(1)

                Text(item.cardMetadataDisplay)
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
        .shadow(color: .black.opacity(0.025), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }
}
