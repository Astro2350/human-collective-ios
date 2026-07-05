import SwiftUI

struct ArchivePackView: View {
    let pack: CulturePack
    let savedStore: SavedStore

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

                    ForEach(pack.items) { item in
                        NavigationLink {
                            CultureDetailView(item: item, savedStore: savedStore)
                        } label: {
                            CultureCard(item: item)
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
