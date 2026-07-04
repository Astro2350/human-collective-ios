import SwiftUI

struct CultureCard: View {
    let item: CultureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CultureAsyncImage(imageURL: item.imageURL, aspectRatio: 1.28)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    CategoryChip(category: item.category)
                    Spacer(minLength: 8)
                    Text(item.dateDisplay)
                        .font(.caption)
                        .foregroundStyle(HCTheme.mutedInk)
                        .lineLimit(1)
                }

                Text(item.title)
                    .font(.cultureTitle(22))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.placeDisplay)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(2)

                Text(item.hook)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(2)
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

