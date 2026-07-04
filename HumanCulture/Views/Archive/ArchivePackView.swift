import SwiftUI

struct ArchivePackView: View {
    let pack: CulturePack
    let savedStore: SavedStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(CultureFormatters.weekRange(startDate: pack.startDate, endDate: pack.endDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HCTheme.clay)

                    Text(pack.title)
                        .font(.cultureTitle(34))
                        .foregroundStyle(HCTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(pack.subtitle)
                        .font(.callout)
                        .foregroundStyle(HCTheme.secondaryInk)
                        .lineSpacing(3)
                }
                .padding(.top, 8)

                ForEach(pack.items) { item in
                    NavigationLink {
                        CultureDetailView(item: item, savedStore: savedStore)
                    } label: {
                        CultureCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HCTheme.pagePadding)
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .background(HCTheme.background)
    }
}

