import SwiftUI

struct ArchivePackView: View {
    let pack: CulturePack
    let savedStore: SavedStore
    @Binding var rootTabBarHiddenDepth: Int

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(CultureFormatters.weekRange(startDate: pack.startDate, endDate: pack.endDate))
                            .font(.cultureKicker())
                            .textCase(.uppercase)
                            .foregroundStyle(HCTheme.clay)

                        Text(pack.title)
                            .font(.cultureTitle(38))
                            .foregroundStyle(HCTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(pack.subtitle)
                            .font(.callout)
                            .foregroundStyle(HCTheme.secondaryInk)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, HCTheme.screenTopPadding)

                    if let featuredItem = pack.featuredItem {
                        archiveItemLink(featuredItem) {
                            ArchivePackFeaturedItemCard(item: featuredItem)
                                .frame(width: contentWidth, alignment: .leading)
                        }
                    }

                    let remainingItems = Array(pack.items.dropFirst())
                    if !remainingItems.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("The week")
                                .font(.cultureKicker())
                                .textCase(.uppercase)
                                .foregroundStyle(HCTheme.clay)

                            ForEach(remainingItems) { item in
                                archiveItemLink(item) {
                                    CultureCard(item: item)
                                        .frame(width: contentWidth, alignment: .leading)
                                }
                            }
                        }
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

    private func archiveItemLink<Label: View>(
        _ item: CultureItem,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            CultureDetailView(item: item, savedStore: savedStore)
                .rootTabBarHidden($rootTabBarHiddenDepth)
        } label: {
            label()
        }
        .buttonStyle(.cultureCard)
    }
}

private struct ArchivePackFeaturedItemCard: View {
    let item: CultureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 1.04,
                cornerRadius: 0,
                accessibilityLabel: item.title
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.cultureTitle(30))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.creatorDisplay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(2)

                Text(item.cardMetadataDisplay)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(2)

                Text(item.hook)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
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
