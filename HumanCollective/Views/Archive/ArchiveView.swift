import MapKit
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
                    .presentationDetents([.large])
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

                        Text("Choose what works for you. Every level unlocks the same archive and helps cover research, upkeep, and new improvements.")
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
                        PaywallBenefitRow(text: "All past daily pieces and weekly collections")
                        PaywallBenefitRow(text: "Every map, timeline, creator, and source")
                        PaywallBenefitRow(text: "Lower levels keep access open; higher levels help fund more updates")
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

private enum ArchiveItemCollection {
    static func uniqueItems(_ items: [CultureItem]) -> [CultureItem] {
        var seen = Set<String>()
        return items.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
    }
}

private struct FullArchiveDiscoveryView: View {
    let items: [CultureItem]
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    @State private var selectedYear = ArchiveTimelineScale.defaultYear
    @State private var selectedLatitude = 26.8206
    @State private var selectedLongitude = 30.8025

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

    private var timeFilteredItems: [CultureItem] {
        datedItems
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.year - selectedYear)
                let rhsDistance = abs(rhs.year - selectedYear)
                return lhsDistance == rhsDistance ? lhs.item.title < rhs.item.title : lhsDistance < rhsDistance
            }
            .prefix(14)
            .map(\.item)
    }

    private var mapPoints: [ArchiveMapPoint] {
        timeFilteredItems.compactMap(ArchiveMapPoint.make(from:))
    }

    private var selectedCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: selectedLatitude, longitude: selectedLongitude)
    }

    private var selectedRegion: ArchiveMapRegion {
        ArchiveMapRegion.region(latitude: selectedLatitude, longitude: selectedLongitude)
    }

    private var nearbyItems: [CultureItem] {
        mapPoints
            .sorted {
                $0.distanceKilometers(to: selectedCoordinate) < $1.distanceKilometers(to: selectedCoordinate)
            }
            .prefix(4)
            .map(\.item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ArchiveSectionHeader(title: "Explore")

            VStack(alignment: .leading, spacing: 13) {
                ArchiveToolHeader(title: "Timeline")

                ArchiveTimelineWheel(
                    selectedYear: $selectedYear,
                    bounds: ArchiveTimelineScale.bounds(for: datedItems.map(\.year))
                )

                ArchiveFilteredResultHeader(
                    title: ArchiveItemDateParser.displayYear(selectedYear),
                    subtitle: nil,
                    count: timeFilteredItems.count
                )
            }

            VStack(alignment: .leading, spacing: 13) {
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
                .frame(height: 220)

                ArchiveFilteredResultHeader(
                    title: "Near \(selectedRegion.title)",
                    subtitle: nil,
                    count: nearbyItems.count
                )

                ArchiveInlineResultList(
                    items: nearbyItems,
                    savedStore: savedStore,
                    rootTabBarHiddenDepth: $rootTabBarHiddenDepth
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: timeFilteredItems.map(\.id))
        .animation(.easeInOut(duration: 0.2), value: nearbyItems.map(\.id))
        .sensoryFeedback(.selection, trigger: Int(selectedYear.rounded()))
        .sensoryFeedback(.selection, trigger: selectedRegion.id)
        .onAppear {
            moveSelectionToFirstMapPoint(animated: false)
        }
        .onChange(of: Int(selectedYear.rounded())) { _, _ in
            moveSelectionToFirstMapPoint(animated: true)
        }
    }

    private func moveSelectionToFirstMapPoint(animated: Bool) {
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
            .font(.cultureTitle(27))
            .foregroundStyle(HCTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ArchiveInlineResultList: View {
    let items: [CultureItem]
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

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
        .animation(.easeInOut(duration: 0.2), value: items.map(\.id))
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
                Text(item.title)
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
        VStack(alignment: .leading, spacing: 7) {
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
            .frame(height: 90)
            .clipped()
            .background(HCTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
            .overlay(alignment: .center) {
                VStack(spacing: 34) {
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
            .accessibilityValue(ArchiveItemDateParser.displayYear(selectedYear))

            HStack {
                Text(ArchiveItemDateParser.displayYear(bounds.lowerBound))
                Spacer()
                Text(ArchiveItemDateParser.displayYear(bounds.upperBound))
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(HCTheme.mutedInk)
        }
        .padding(10)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
    }
}

private enum ArchiveTimelineScale {
    static let defaultYear = 0.0

    static func bounds(for years: [Double]) -> ClosedRange<Double> {
        let minYear = min(years.min() ?? -2200, -2200)
        let maxYear = max(years.max() ?? 2026, 2026)
        return minYear...maxYear
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
    static func estimatedYear(for dateDisplay: String) -> Double? {
        let lowercase = dateDisplay.lowercased()
        let values = numbers(in: dateDisplay)
        guard !values.isEmpty else { return nil }

        let isBCE = lowercase.contains("bce") || lowercase.contains("bc")
        let isCentury = lowercase.contains("century")
        let years = values.map { value -> Double in
            if isCentury {
                let midpoint = (Double(value - 1) * 100) + 50
                return isBCE ? -midpoint : midpoint
            }

            return isBCE ? -Double(value) : Double(value)
        }

        return years.reduce(0, +) / Double(years.count)
    }

    static func displayYear(_ year: Double) -> String {
        let roundedYear = Int(year.rounded())
        if roundedYear < 0 {
            return "\(abs(roundedYear)) BCE"
        }

        return "\(roundedYear) CE"
    }

    private static func numbers(in text: String) -> [Int] {
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, range: range).compactMap { match in
            Int(nsText.substring(with: match.range))
        }
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
                    .frame(width: contentWidth, height: 250)

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

    @State private var position: MapCameraPosition = .automatic

    private var region: MKCoordinateRegion {
        ArchiveMapPoint.region(containing: points)
    }

    private var pointSignature: String {
        points.map(\.id).joined(separator: "|")
    }

    private var selectedPointID: String? {
        points.first { $0.isNear(selectedCoordinate) }?.id
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                ForEach(points) { point in
                    Annotation("", coordinate: point.coordinate) {
                        Button {
                            onSelectCoordinate(point.coordinate)
                        } label: {
                            ArchiveMapDot(isSelected: selectedPointID == point.id)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if selectedPointID == nil {
                    Annotation("", coordinate: selectedCoordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(HCTheme.clay)
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let coordinate = proxy.convert(value.location, from: .local) {
                            onSelectCoordinate(coordinate)
                        }
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                    .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
            }
            .onAppear {
                position = .region(region)
            }
            .onChange(of: pointSignature) { _, _ in
                withAnimation(.easeInOut(duration: 0.24)) {
                    position = .region(region)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: selectedPointID)
        }
    }
}

private struct ArchiveMapDot: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? HCTheme.clay : HCTheme.blueStone.opacity(0.72))
            .frame(width: isSelected ? 15 : 10, height: isSelected ? 15 : 10)
            .overlay {
                Circle()
                    .stroke(HCTheme.surface, lineWidth: isSelected ? 2.6 : 2)
            }
            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 1)
            .contentShape(Circle())
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
