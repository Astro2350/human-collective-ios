import SwiftUI

struct FeaturedCultureCard: View {
    let item: CultureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CultureAsyncImage(imageURL: item.imageURL, aspectRatio: 1.08)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Featured")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(HCTheme.clay)
                    Spacer()
                    CategoryChip(category: item.category)
                }

                Text(item.title)
                    .font(.cultureTitle(30))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(item.placeDisplay) - \(item.dateDisplay)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.hook)
                    .font(.body)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
        }
        .padding(12)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: 1)
        }
    }
}

