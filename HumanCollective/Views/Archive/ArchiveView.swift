import MapKit
import SwiftUI
import UIKit

struct ArchiveView: View {
    private let freeArchivePackLimit = 2
    private let pastWeekBatchSize = 5

    let savedStore: SavedStore
    let fullArchiveStore: FullArchiveStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var isShowingFullArchivePaywall = false
    @State private var visiblePastWeekCount = 5
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
            let visiblePackSignature = ArchiveItemCollection.packIDSignature(visiblePacks)
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
                        if fullArchiveStore.hasFullArchiveAccess {
                            FullArchiveDiscoveryView(
                                items: ArchiveItemCollection.uniqueItems(visiblePacks.flatMap(\.items)),
                                savedStore: savedStore,
                                rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                            )
                            .frame(width: contentWidth, alignment: .leading)
                        }

                        if let featuredPack = visiblePacks.first {
                            archivePackLink(featuredPack) {
                                ArchiveFeaturedWeekCard(pack: featuredPack)
                                    .frame(width: contentWidth, alignment: .leading)
                            }
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

                        let earlierPacks = Array(visiblePacks.dropFirst())
                        if !earlierPacks.isEmpty {
                            let loadedPastWeeks = Array(earlierPacks.prefix(visiblePastWeekCount))
                            let remainingPastWeekCount = max(earlierPacks.count - loadedPastWeeks.count, 0)

                            VStack(alignment: .leading, spacing: 16) {
                                ArchiveSectionHeader(title: "Past weeks")

                                ForEach(loadedPastWeeks) { pack in
                                    archivePackLink(pack) {
                                        ArchiveWeekCard(pack: pack)
                                            .frame(width: contentWidth, alignment: .leading)
                                    }
                                }

                                if remainingPastWeekCount > 0 {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            visiblePastWeekCount = min(
                                                visiblePastWeekCount + pastWeekBatchSize,
                                                earlierPacks.count
                                            )
                                        }
                                    } label: {
                                        ArchiveLoadMoreWeeksLabel()
                                            .frame(width: contentWidth, alignment: .center)
                                    }
                                    .buttonStyle(.plain)
                                }
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: visiblePackSignature) { _, _ in
                visiblePastWeekCount = pastWeekBatchSize
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
            return "Unlock \(lockedPackCount) more weekly \(lockedPackCount == 1 ? "archive" : "archives"), the interactive timeline and maps, and creators."
        }

        return "Explore every past piece with the interactive timeline and maps, plus creators and sources."
    }

    private var accessibilityLabel: String {
        "Full Archive. \(subtitle)"
    }
}

private struct FullArchivePaywallView: View {
    let fullArchiveStore: FullArchiveStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
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

                        Text("Pick a level. Each one unlocks the full archive, interactive timeline and maps.")
                            .font(.title3)
                            .foregroundStyle(HCTheme.secondaryInk)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Same archive, different support levels")
                            .font(.cultureKicker())
                            .textCase(.uppercase)
                            .foregroundStyle(HCTheme.clay)

                        if fullArchiveStore.supportOptions.isEmpty {
                            FullArchiveUnavailableOptionsView()
                        } else {
                            VStack(spacing: 9) {
                                ForEach(fullArchiveStore.supportOptions) { option in
                                    FullArchiveSupportOptionRow(
                                        option: option,
                                        isBusy: isBusy,
                                        isPurchasing: fullArchiveStore.activePurchaseProductID == option.id
                                    ) {
                                        Task { await fullArchiveStore.purchase(productID: option.id) }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        PaywallBenefitRow(text: "Past pieces and weekly collections")
                        PaywallBenefitRow(text: "Interactive timeline and maps")
                        PaywallBenefitRow(text: "Creators, sources, and updates")
                    }

                    if let message = fullArchiveStore.statusMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(HCTheme.clay)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(HCTheme.pagePadding)
            }

            VStack(spacing: 12) {
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
            .padding(.horizontal, HCTheme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, HCTheme.pagePadding)
            .background(HCTheme.background)
        }
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

private struct FullArchiveSupportOptionRow: View {
    let option: FullArchiveStore.SupportOption
    let isBusy: Bool
    let isPurchasing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(option.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(HCTheme.ink)

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(HCTheme.secondaryInk)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    if isPurchasing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(HCTheme.blueStone)
                    }

                    Text(option.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HCTheme.blueStone)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                    .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("\(option.title), \(option.displayPrice). \(option.subtitle)")
    }
}

private struct FullArchiveUnavailableOptionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Support options are being set up.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(HCTheme.ink)

            Text("Each level will unlock the same Full Archive once this is ready.")
                .font(.caption)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
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

private struct ArchiveLoadMoreWeeksLabel: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))

            Text("Load more")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(HCTheme.ink)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(HCTheme.surfaceRaised.opacity(0.82), in: Capsule())
        .overlay {
            Capsule()
                .stroke(HCTheme.line.opacity(0.58), lineWidth: HCTheme.hairline)
        }
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Load more past weeks")
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
                let words = searchableWords(for: item)
                return containsAnyWord(
                    words,
                    [
                        "bear", "bird", "birds", "bull", "cat", "deer", "dog",
                        "elephant", "fish", "frog", "hedgehog", "hippo",
                        "hippopotamus", "horse", "lion", "monkey", "octopus",
                        "owl", "rabbit", "rhinoceros", "snail", "turtle",
                        "whale", "whales"
                    ]
                ) || containsAnyPhrase(
                    text,
                    [
                        "bird-shaped",
                        "bull-dog",
                        "killer whale",
                        "owl-shaped",
                        "pussycat"
                    ]
                )
            }),
            ("faces", "Faces and masks", "Portraits, masks, and figures with presence", { item in
                let title = item.title.lowercased()
                let words = words(in: title)
                return item.id.contains("lewis-chessmen") ||
                    item.id.contains("terracotta-warriors") ||
                    containsAnyWord(
                        words,
                        ["face", "faces", "mask", "masks", "portrait", "portraits"]
                    ) ||
                    containsAnyPhrase(title, ["portrait vessel"])
            }),
            ("knowledge", "Maps and knowledge", "Books, tools, diagrams, and ways of reading the world", { item in
                let text = searchableText(for: item)
                let words = searchableWords(for: item)
                return item.category == .map ||
                    item.category == .manuscript ||
                    item.category == .tool ||
                    containsAnyWord(
                        words,
                        [
                            "astrolabe", "bible", "book", "books", "codex",
                            "hieroglyph", "hieroglyphs", "inscription", "law",
                            "laws", "map", "maps", "page", "pages", "scroll"
                        ]
                    ) ||
                    containsAnyPhrase(text, ["rosetta stone"])
            }),
            ("small", "Small wonders", "Netsuke, jewelry, amulets, and compact objects", { item in
                let words = searchableWords(for: item)
                return item.category == .jewelry ||
                    containsAnyWord(
                        words,
                        [
                            "amulet", "amulets", "bead", "beads", "chessmen",
                            "intaglio", "miniature", "miniatures", "netsuke",
                            "pendant", "pendants", "perfume", "ring", "rings",
                            "scarab", "scaraboid", "small", "tiny", "whistle"
                        ]
                    )
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

    private static func searchableWords(for item: CultureItem) -> Set<String> {
        words(in: searchableText(for: item))
    }

    private static func words(in text: String) -> Set<String> {
        Set(text.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }

    private static func containsAnyWord(_ words: Set<String>, _ candidates: [String]) -> Bool {
        candidates.contains { words.contains($0) }
    }

    private static func containsAnyPhrase(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
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
                Text(item.displayTitle)
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

private enum ArchiveItemCollection {
    static func uniqueItems(_ items: [CultureItem]) -> [CultureItem] {
        var seen = Set<String>()
        return items.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
    }

    static func idSignature(_ items: [CultureItem]) -> String {
        items.reduce(into: "") { signature, item in
            if !signature.isEmpty {
                signature.append("|")
            }
            signature.append(item.id)
        }
    }

    static func packIDSignature(_ packs: [CulturePack]) -> String {
        packs.reduce(into: "") { signature, pack in
            if !signature.isEmpty {
                signature.append("|")
            }
            signature.append(pack.id)
        }
    }
}

private struct ArchiveDiscoveryData {
    let items: [CultureItem]
    let datedItems: [ArchiveTimelineItem]
    let timelineBounds: ClosedRange<Double>
    private let mapPointsByItemID: [String: ArchiveMapPoint]

    init(items: [CultureItem]) {
        var parsedItems: [ArchiveTimelineItem] = []
        parsedItems.reserveCapacity(items.count)

        var mapPointsByItemID: [String: ArchiveMapPoint] = [:]
        mapPointsByItemID.reserveCapacity(items.count)

        for item in items {
            if let year = ArchiveItemDateParser.estimatedYear(for: item.dateDisplay) {
                parsedItems.append(ArchiveTimelineItem(item: item, year: year))
            }

            if let mapPoint = ArchiveMapPoint.make(from: item) {
                mapPointsByItemID[item.id] = mapPoint
            }
        }

        parsedItems.sort { lhs, rhs in
            lhs.year == rhs.year ? lhs.item.title < rhs.item.title : lhs.year < rhs.year
        }

        self.items = items
        self.datedItems = parsedItems
        self.timelineBounds = ArchiveTimelineScale.bounds(for: parsedItems.map { $0.year })
        self.mapPointsByItemID = mapPointsByItemID
    }

    func itemsClosest(to year: Double, limit: Int) -> [CultureItem] {
        datedItems
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.year - year)
                let rhsDistance = abs(rhs.year - year)
                return lhsDistance == rhsDistance ? lhs.item.title < rhs.item.title : lhsDistance < rhsDistance
            }
            .prefix(limit)
            .map(\.item)
    }

    func mapPoints(for items: [CultureItem]) -> [ArchiveMapPoint] {
        items.compactMap { mapPointsByItemID[$0.id] }
    }
}

private struct FullArchiveDiscoveryView: View {
    private let data: ArchiveDiscoveryData
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    @State private var selectedYear = ArchiveTimelineScale.defaultYear
    @State private var selectedLatitude = 26.8206
    @State private var selectedLongitude = 30.8025

    init(items: [CultureItem], savedStore: SavedStore, rootTabBarHiddenDepth: Binding<Int>) {
        self.data = ArchiveDiscoveryData(items: items)
        self.savedStore = savedStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
    }

    private var selectedCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: selectedLatitude, longitude: selectedLongitude)
    }

    private var selectedRegion: ArchiveMapRegion {
        ArchiveMapRegion.region(latitude: selectedLatitude, longitude: selectedLongitude)
    }

    var body: some View {
        let timeFilteredItems = data.itemsClosest(to: selectedYear, limit: 14)
        let mapPoints = data.mapPoints(for: timeFilteredItems)
        let nearbyItems = nearbyItems(from: mapPoints)
        let timeFilteredSignature = ArchiveItemCollection.idSignature(timeFilteredItems)
        let nearbySignature = ArchiveItemCollection.idSignature(nearbyItems)

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                ArchiveToolHeader(title: "Timeline")

                ArchiveTimelineWheel(
                    selectedYear: $selectedYear,
                    bounds: data.timelineBounds
                )
            }

            VStack(alignment: .leading, spacing: 9) {
                ArchiveToolHeader(title: "Map")

                ArchiveInteractiveMap(
                    points: mapPoints,
                    selectedCoordinate: selectedCoordinate
                ) { coordinate in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedLatitude = coordinate.latitude
                        selectedLongitude = coordinate.longitude
                    }
                }
                .aspectRatio(1.58, contentMode: .fit)

                ArchiveInlineResultList(
                    items: nearbyItems,
                    savedStore: savedStore,
                    rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: timeFilteredSignature)
        .animation(.easeInOut(duration: 0.2), value: nearbySignature)
        .sensoryFeedback(.selection, trigger: Int(selectedYear.rounded()))
        .sensoryFeedback(.selection, trigger: selectedRegion.id)
        .onAppear {
            moveSelectionToFirstMapPoint(in: mapPoints, animated: false)
        }
        .onChange(of: Int(selectedYear.rounded())) { _, _ in
            moveSelectionToFirstMapPoint(in: mapPoints, animated: true)
        }
    }

    private func nearbyItems(from mapPoints: [ArchiveMapPoint]) -> [CultureItem] {
        mapPoints
            .sorted {
                $0.distanceKilometers(to: selectedCoordinate) < $1.distanceKilometers(to: selectedCoordinate)
            }
            .prefix(4)
            .map(\.item)
    }

    private func moveSelectionToFirstMapPoint(in mapPoints: [ArchiveMapPoint], animated: Bool) {
        guard let point = mapPoints.first else { return }

        let update = {
            selectedLatitude = point.latitude
            selectedLongitude = point.longitude
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.18)) {
                update()
            }
        } else {
            update()
        }
    }
}

private struct ArchiveToolHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.cultureTitle(24))
            .foregroundStyle(HCTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ArchiveInlineResultList: View {
    let items: [CultureItem]
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    private var itemSignature: String {
        ArchiveItemCollection.idSignature(items)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                NavigationLink {
                    CultureDetailView(item: item, savedStore: savedStore)
                        .rootTabBarHidden($rootTabBarHiddenDepth)
                } label: {
                    ArchiveCompactItemRow(item: item)
                }
                .buttonStyle(.cultureCard)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: itemSignature)
    }
}

private struct ArchiveCompactItemRow: View {
    let item: CultureItem

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 1.0,
                cornerRadius: 5,
                accessibilityLabel: item.title
            )
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.cardMetadataDisplay)
                    .font(.caption)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.45), lineWidth: HCTheme.hairline)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ArchiveTimelineView: View {
    let items: [CultureItem]
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    @State private var selectedYear = ArchiveTimelineScale.defaultYear

    private var datedItems: [ArchiveTimelineItem] {
        items.compactMap { item in
            guard let year = ArchiveItemDateParser.estimatedYear(for: item.dateDisplay) else {
                return nil
            }

            return ArchiveTimelineItem(item: item, year: year)
        }
        .sorted { lhs, rhs in
            lhs.year == rhs.year ? lhs.item.title < rhs.item.title : lhs.year < rhs.year
        }
    }

    private var filteredItems: [CultureItem] {
        let nearbyItems = datedItems
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.year - selectedYear)
                let rhsDistance = abs(rhs.year - selectedYear)
                return lhsDistance == rhsDistance ? lhs.item.title < rhs.item.title : lhsDistance < rhsDistance
            }
            .prefix(10)

        return nearbyItems.map(\.item)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Full Archive")
                            .font(.cultureKicker())
                            .textCase(.uppercase)
                            .foregroundStyle(HCTheme.clay)

                        Text("Timeline")
                            .font(.cultureTitle(38))
                            .foregroundStyle(HCTheme.ink)
                    }
                    .padding(.top, HCTheme.screenTopPadding)

                    ArchiveTimelineWheel(
                        selectedYear: $selectedYear,
                        bounds: ArchiveTimelineScale.bounds(for: datedItems.map(\.year))
                    )
                    .frame(width: contentWidth)

                    ArchiveFilteredResultHeader(
                        title: ArchiveItemDateParser.displayYear(selectedYear),
                        subtitle: nil,
                        count: filteredItems.count
                    )
                    .frame(width: contentWidth, alignment: .leading)

                    ForEach(filteredItems) { item in
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
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(HCTheme.background)
    }
}

private struct ArchiveTimelineWheel: View {
    @Binding var selectedYear: Double
    let bounds: ClosedRange<Double>

    private var selectedYearBinding: Binding<Int> {
        Binding(
            get: { Int(selectedYear.rounded()) },
            set: { year in
                withAnimation(.easeInOut(duration: 0.16)) {
                    selectedYear = Double(year)
                }
            }
        )
    }

    private var yearOptions: [Int] {
        let lowerBound = Int(bounds.lowerBound.rounded())
        let upperBound = Int(bounds.upperBound.rounded())
        let start = (lowerBound / 25) * 25
        let end = ((upperBound + 24) / 25) * 25
        var values = Array(stride(from: start, through: end, by: 25))
        values.append(contentsOf: [lowerBound, 0, upperBound])
        return Array(Set(values))
            .filter { lowerBound...upperBound ~= $0 }
            .sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ArchiveHistoricalPeriod.title(for: selectedYear))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)
                .padding(.leading, 2)
                .accessibilityLabel("Period")
                .accessibilityValue(ArchiveHistoricalPeriod.title(for: selectedYear))

            Picker("Time", selection: selectedYearBinding) {
                ForEach(yearOptions, id: \.self) { year in
                    Text(ArchiveItemDateParser.displayYear(Double(year)))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HCTheme.ink)
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 74)
            .clipped()
            .background(HCTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
            .overlay(alignment: .center) {
                VStack(spacing: 27) {
                    Rectangle()
                        .fill(HCTheme.line.opacity(0.55))
                        .frame(height: HCTheme.hairline)
                    Rectangle()
                        .fill(HCTheme.line.opacity(0.55))
                        .frame(height: HCTheme.hairline)
                }
                .padding(.horizontal, 12)
                .allowsHitTesting(false)
            }
            .accessibilityLabel("Time")
            .accessibilityValue("\(ArchiveItemDateParser.displayYear(selectedYear)), \(ArchiveHistoricalPeriod.title(for: selectedYear))")

            HStack {
                Text(ArchiveItemDateParser.displayYear(bounds.lowerBound))
                Spacer()
                Text(ArchiveItemDateParser.displayYear(bounds.upperBound))
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(HCTheme.mutedInk)
        }
        .padding(8)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
    }
}

private enum ArchiveHistoricalPeriod {
    static func title(for year: Double) -> String {
        switch year {
        case ..<(-3000):
            return "Prehistoric"
        case -3000..<(-800):
            return "Early ancient"
        case -800..<500:
            return "Ancient world"
        case 500..<1000:
            return "Early medieval"
        case 1000..<1400:
            return "Medieval"
        case 1400..<1600:
            return "Renaissance"
        case 1600..<1750:
            return "Early modern"
        case 1750..<1850:
            return "Age of revolutions"
        case 1850..<1914:
            return "Modern era"
        case 1914..<1945:
            return "World wars era"
        case 1945..<1990:
            return "Postwar era"
        default:
            return "Contemporary"
        }
    }
}

private enum ArchiveTimelineScale {
    static let defaultYear = 0.0
    static let oldestReasonableYear = -12_000.0

    static func bounds(for years: [Double]) -> ClosedRange<Double> {
        let validYears = years.filter(isReasonableYear)
        let minYear = min(validYears.min() ?? -2200, -2200)
        let maxYear = max(validYears.max() ?? currentYear, currentYear)
        return minYear...maxYear
    }

    static func isReasonableYear(_ year: Double) -> Bool {
        oldestReasonableYear...currentYear ~= year
    }

    static var currentYear: Double {
        Double(max(2026, Calendar.current.component(.year, from: Date())))
    }
}

private struct ArchiveTimelineItem: Identifiable {
    let item: CultureItem
    let year: Double

    var id: String {
        item.id
    }
}

private enum ArchiveItemDateParser {
    private static let centuryRegex = try? NSRegularExpression(
        pattern: #"(\d{1,2})(?:st|nd|rd|th)?(?:\s*[-–—]\s*(\d{1,2})(?:st|nd|rd|th)?)?\s*(bce|bc|ce|ad)?"#
    )
    private static let yearRegex = try? NSRegularExpression(
        pattern: #"(\d{1,4})(?:\s*[-–—]\s*(\d{1,4}))?\s*(bce|bc|ce|ad)?"#
    )

    static func estimatedYear(for dateDisplay: String) -> Double? {
        let lowercase = dateDisplay.lowercased()
        let values = numbers(in: dateDisplay, isCentury: lowercase.contains("century"))
        guard !values.isEmpty else { return nil }

        let hasBCE = lowercase.contains("bce") || lowercase.contains("bc")
        let hasCE = lowercase.contains("ce") || lowercase.contains("ad")
        let isCentury = lowercase.contains("century")
        let years = values.compactMap { value -> Double? in
            guard value.number > 0 else { return nil }

            if isCentury {
                guard value.number <= 40 else { return nil }

                let midpoint = (Double(value.number - 1) * 100) + 50
                let isBCE = value.era.map(isBCEEra) ?? (hasBCE && !hasCE)
                let year = isBCE ? -midpoint : midpoint
                return ArchiveTimelineScale.isReasonableYear(year) ? year : nil
            }

            let isBCE = value.era.map(isBCEEra) ?? (hasBCE && !hasCE)
            let maximumReasonableYear = isBCE
                ? abs(Int(ArchiveTimelineScale.oldestReasonableYear))
                : Int(ArchiveTimelineScale.currentYear)
            guard value.number <= maximumReasonableYear else { return nil }

            let year = isBCE ? -Double(value.number) : Double(value.number)
            return ArchiveTimelineScale.isReasonableYear(year) ? year : nil
        }
        guard !years.isEmpty else { return nil }

        return years.reduce(0, +) / Double(years.count)
    }

    static func displayYear(_ year: Double) -> String {
        let roundedYear = Int(year.rounded())
        if roundedYear < 0 {
            return "\(abs(roundedYear)) BCE"
        }

        return "\(roundedYear) CE"
    }

    private static func numbers(in text: String, isCentury: Bool) -> [DatedNumber] {
        guard let regex = isCentury ? centuryRegex : yearRegex else { return [] }

        let nsText = text.lowercased() as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: nsText as String, range: range).flatMap { match -> [DatedNumber] in
            let era = string(from: match, at: 3, in: nsText)
            var values: [DatedNumber] = []

            if let firstValue = int(from: match, at: 1, in: nsText) {
                values.append(DatedNumber(number: firstValue, era: era))
            }

            if let secondValue = int(from: match, at: 2, in: nsText) {
                values.append(DatedNumber(number: secondValue, era: era))
            }

            return values
        }
    }

    private static func int(from match: NSTextCheckingResult, at index: Int, in text: NSString) -> Int? {
        guard index < match.numberOfRanges else { return nil }

        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }

        return Int(text.substring(with: range))
    }

    private static func string(from match: NSTextCheckingResult, at index: Int, in text: NSString) -> String? {
        guard index < match.numberOfRanges else { return nil }

        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }

        return text.substring(with: range).lowercased()
    }

    private static func isBCEEra(_ era: String) -> Bool {
        era == "bce" || era == "bc"
    }

    private struct DatedNumber {
        let number: Int
        let era: String?
    }
}

private struct ArchiveMapExploreView: View {
    let items: [CultureItem]
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    @State private var selectedLatitude = 26.8206
    @State private var selectedLongitude = 30.8025

    private var points: [ArchiveMapPoint] {
        items.compactMap(ArchiveMapPoint.make(from:))
    }

    private var selectedCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: selectedLatitude, longitude: selectedLongitude)
    }

    private var selectedRegion: ArchiveMapRegion {
        ArchiveMapRegion.region(latitude: selectedLatitude, longitude: selectedLongitude)
    }

    private var nearbyItems: [CultureItem] {
        points
            .sorted {
                $0.distanceKilometers(to: selectedCoordinate) < $1.distanceKilometers(to: selectedCoordinate)
            }
            .prefix(10)
            .map(\.item)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Full Archive")
                            .font(.cultureKicker())
                            .textCase(.uppercase)
                            .foregroundStyle(HCTheme.clay)

                        Text("Map")
                            .font(.cultureTitle(38))
                            .foregroundStyle(HCTheme.ink)
                    }
                    .padding(.top, HCTheme.screenTopPadding)

                    ArchiveInteractiveMap(
                        points: points,
                        selectedCoordinate: selectedCoordinate
                    ) { coordinate in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedLatitude = coordinate.latitude
                            selectedLongitude = coordinate.longitude
                        }
                    }
                    .frame(width: contentWidth, height: contentWidth)

                    ArchiveFilteredResultHeader(
                        title: "Near \(selectedRegion.title)",
                        subtitle: nil,
                        count: nearbyItems.count
                    )
                    .frame(width: contentWidth, alignment: .leading)

                    ForEach(nearbyItems) { item in
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
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(HCTheme.background)
    }
}

private struct ArchiveInteractiveMap: View {
    let points: [ArchiveMapPoint]
    let selectedCoordinate: CLLocationCoordinate2D
    let onSelectCoordinate: (CLLocationCoordinate2D) -> Void

    var body: some View {
        ArchiveAppleMapView(
            points: points,
            selectedCoordinate: selectedCoordinate,
            onSelectCoordinate: onSelectCoordinate
        )
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .background(.black, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
        .accessibilityLabel("Interactive globe")
        .accessibilityHint("Drag to rotate, pinch to zoom, or tap a place to filter nearby pieces.")
    }
}

private struct ArchiveAppleMapView: UIViewRepresentable {
    let points: [ArchiveMapPoint]
    let selectedCoordinate: CLLocationCoordinate2D
    let onSelectCoordinate: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        context.coordinator.makeView()
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.update(
            mapView: uiView,
            points: points,
            selectedCoordinate: selectedCoordinate,
            onSelectCoordinate: onSelectCoordinate
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        private var pointSignature = ""
        private var selectedSignature = ""
        private var onSelectCoordinate: (CLLocationCoordinate2D) -> Void = { _ in }
        private var isUpdatingCamera = false

        private let markerReuseIdentifier = "ArchiveAppleMapMarker"
        private let minimumCameraDistance: CLLocationDistance = 1_100_000
        private let maximumCameraDistance: CLLocationDistance = 82_000_000
        private let defaultCameraDistance: CLLocationDistance = 68_000_000

        func makeView() -> MKMapView {
            let view = MKMapView(frame: .zero)
            view.delegate = self
            view.backgroundColor = .black
            view.overrideUserInterfaceStyle = .dark
            view.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            view.isRotateEnabled = false
            view.isPitchEnabled = false
            view.isScrollEnabled = true
            view.isZoomEnabled = true
            view.showsCompass = false
            view.showsScale = false
            view.showsUserLocation = false
            view.cameraZoomRange = MKMapView.CameraZoomRange(
                minCenterCoordinateDistance: minimumCameraDistance,
                maxCenterCoordinateDistance: maximumCameraDistance
            )

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tapGesture.delegate = self
            view.addGestureRecognizer(tapGesture)

            setCamera(on: view, to: CLLocationCoordinate2D(latitude: 20, longitude: 15), animated: false)
            return view
        }

        func update(
            mapView: MKMapView,
            points: [ArchiveMapPoint],
            selectedCoordinate: CLLocationCoordinate2D,
            onSelectCoordinate: @escaping (CLLocationCoordinate2D) -> Void
        ) {
            self.onSelectCoordinate = onSelectCoordinate

            let nextPointSignature = points.reduce(into: "") { signature, point in
                if !signature.isEmpty {
                    signature.append("|")
                }
                signature.append(point.id)
            }
            if nextPointSignature != pointSignature {
                pointSignature = nextPointSignature
                rebuildAnnotations(on: mapView, with: points)
            }

            let nextSelectedSignature = Self.signature(for: selectedCoordinate)
            if nextSelectedSignature != selectedSignature {
                selectedSignature = nextSelectedSignature
                refreshAnnotationViews(on: mapView)
                setCamera(on: mapView, to: selectedCoordinate, animated: true)
            }
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let mapView = gesture.view as? MKMapView else { return }

            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            select(coordinate, on: mapView, shouldFocus: true)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let archiveAnnotation = annotation as? ArchiveMapAnnotation else {
                return nil
            }

            let view = mapView.dequeueReusableAnnotationView(withIdentifier: markerReuseIdentifier) ??
                MKAnnotationView(annotation: annotation, reuseIdentifier: markerReuseIdentifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.displayPriority = .required
            view.collisionMode = .circle
            configureMarkerView(view, for: archiveAnnotation)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let annotation = annotation as? ArchiveMapAnnotation else { return }

            mapView.deselectAnnotation(annotation, animated: false)
            select(annotation.coordinate, on: mapView, shouldFocus: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !isUpdatingCamera else { return }

            refreshAnnotationViews(on: mapView)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            !(touch.view is MKAnnotationView)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func rebuildAnnotations(on mapView: MKMapView, with points: [ArchiveMapPoint]) {
            let existingAnnotations = mapView.annotations.compactMap { $0 as? ArchiveMapAnnotation }
            mapView.removeAnnotations(existingAnnotations)
            mapView.addAnnotations(points.map(ArchiveMapAnnotation.init(point:)))
            refreshAnnotationViews(on: mapView)
        }

        private func refreshAnnotationViews(on mapView: MKMapView) {
            for annotation in mapView.annotations {
                guard let annotation = annotation as? ArchiveMapAnnotation,
                      let view = mapView.view(for: annotation) else {
                    continue
                }

                configureMarkerView(view, for: annotation)
            }
        }

        private func select(_ coordinate: CLLocationCoordinate2D, on mapView: MKMapView, shouldFocus: Bool) {
            let normalizedCoordinate = CLLocationCoordinate2D(
                latitude: Self.clampedLatitude(coordinate.latitude),
                longitude: Self.normalizedLongitude(coordinate.longitude)
            )

            selectedSignature = Self.signature(for: normalizedCoordinate)
            refreshAnnotationViews(on: mapView)

            if shouldFocus {
                setCamera(on: mapView, to: normalizedCoordinate, animated: true)
            }

            onSelectCoordinate(normalizedCoordinate)
        }

        private func setCamera(on mapView: MKMapView, to coordinate: CLLocationCoordinate2D, animated: Bool) {
            let currentDistance = mapView.camera.centerCoordinateDistance
            let distance = currentDistance.isFinite && currentDistance > 0
                ? min(max(currentDistance, minimumCameraDistance), maximumCameraDistance)
                : defaultCameraDistance
            let camera = MKMapCamera(
                lookingAtCenter: coordinate,
                fromDistance: distance,
                pitch: 0,
                heading: 0
            )

            isUpdatingCamera = true
            mapView.setCamera(camera, animated: animated)

            DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.28 : 0.04)) { [weak self] in
                self?.isUpdatingCamera = false
            }
        }

        private func configureMarkerView(_ view: MKAnnotationView, for annotation: ArchiveMapAnnotation) {
            let isSelected = Self.signature(for: annotation.coordinate) == selectedSignature

            view.image = Self.markerImage(isSelected: isSelected)
            view.centerOffset = .zero
            view.alpha = isSelected ? 1 : 0.84
        }

        private static func markerImage(isSelected: Bool) -> UIImage {
            isSelected ? selectedMarkerImage : unselectedMarkerImage
        }

        private static let selectedMarkerImage = makeMarkerImage(isSelected: true)
        private static let unselectedMarkerImage = makeMarkerImage(isSelected: false)

        private static func makeMarkerImage(isSelected: Bool) -> UIImage {
            let size = isSelected ? CGSize(width: 18, height: 18) : CGSize(width: 12, height: 12)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let bounds = CGRect(origin: .zero, size: size)
                let outerColor = UIColor(red: 0.98, green: 0.94, blue: 0.86, alpha: isSelected ? 0.94 : 0.76)
                let innerColor = UIColor(red: 0.55, green: 0.35, blue: 0.24, alpha: 1)

                context.cgContext.setFillColor(outerColor.cgColor)
                context.cgContext.fillEllipse(in: bounds)

                let inset = isSelected ? 4.5 : 3.0
                context.cgContext.setFillColor(innerColor.cgColor)
                context.cgContext.fillEllipse(in: bounds.insetBy(dx: inset, dy: inset))
            }
        }

        private static func clampedLatitude(_ latitude: Double) -> Double {
            min(max(latitude, -85), 85)
        }

        private static func normalizedLongitude(_ longitude: Double) -> Double {
            let shifted = (longitude + 180).truncatingRemainder(dividingBy: 360)
            let positive = shifted < 0 ? shifted + 360 : shifted
            return positive - 180
        }

        private static func signature(for coordinate: CLLocationCoordinate2D) -> String {
            "\(coordinate.latitude.rounded(toPlaces: 3))|\(coordinate.longitude.rounded(toPlaces: 3))"
        }
    }
}

private final class ArchiveMapAnnotation: NSObject, MKAnnotation {
    let point: ArchiveMapPoint

    var coordinate: CLLocationCoordinate2D {
        point.coordinate
    }

    var title: String? {
        point.item.displayTitle
    }

    init(point: ArchiveMapPoint) {
        self.point = point
        super.init()
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private struct ArchiveMapPoint: Identifiable {
    let item: CultureItem
    let latitude: Double
    let longitude: Double
    let region: ArchiveMapRegion

    var id: String {
        item.id
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distanceKilometers(to coordinate: CLLocationCoordinate2D) -> Double {
        let origin = CLLocation(latitude: latitude, longitude: longitude)
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return origin.distance(from: destination) / 1_000
    }

    func isNear(_ coordinate: CLLocationCoordinate2D) -> Bool {
        abs(latitude - coordinate.latitude) < 0.0001 &&
            abs(longitude - coordinate.longitude) < 0.0001
    }

    static func make(from item: CultureItem) -> ArchiveMapPoint? {
        guard let latitude = item.latitude,
              let longitude = item.longitude,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        return ArchiveMapPoint(
            item: item,
            latitude: latitude,
            longitude: longitude,
            region: ArchiveMapRegion.region(latitude: latitude, longitude: longitude)
        )
    }

    static func region(containing points: [ArchiveMapPoint]) -> MKCoordinateRegion {
        guard !points.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 15),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 220)
            )
        }

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let minLatitude = latitudes.min() ?? -60
        let maxLatitude = latitudes.max() ?? 70
        let minLongitude = longitudes.min() ?? -150
        let maxLongitude = longitudes.max() ?? 150
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * 1.28, 36),
            longitudeDelta: max((maxLongitude - minLongitude) * 1.28, 48)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

private struct ArchiveMapRegion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    static let defaultID = "africa-middle-east"

    static let all = [
        ArchiveMapRegion(id: "africa-middle-east", title: "Africa & Middle East", subtitle: "Objects rooted around Africa, Egypt, and nearby regions"),
        ArchiveMapRegion(id: "europe", title: "Europe", subtitle: "Pieces tied to European makers, sites, and collections"),
        ArchiveMapRegion(id: "asia-pacific", title: "Asia & Pacific", subtitle: "Works from East, South, Central, and Pacific cultures"),
        ArchiveMapRegion(id: "americas", title: "Americas", subtitle: "Pieces from North, Central, and South America")
    ]

    static func region(latitude: Double, longitude: Double) -> ArchiveMapRegion {
        if longitude < -25 {
            return all[3]
        }

        if (-25...45).contains(longitude), latitude >= 35 {
            return all[1]
        }

        if (-25...70).contains(longitude) {
            return all[0]
        }

        return all[2]
    }
}

private struct ArchiveFilteredResultHeader: View {
    let title: String
    let subtitle: String?
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.cultureTitle(27))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.clay)
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
