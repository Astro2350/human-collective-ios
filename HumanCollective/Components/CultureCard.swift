import SwiftUI

struct CultureCard: View {
    let item: CultureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: HCTheme.feedImageAspectRatio,
                cornerRadius: 0,
                accessibilityLabel: item.title
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(item.displayTitle)
                    .font(.cultureTitle(24))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Creator: \(item.creatorDisplay)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

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
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
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
