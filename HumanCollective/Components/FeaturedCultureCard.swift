import SwiftUI

struct FeaturedCultureCard: View {
    let item: CultureItem
    var kicker = "Editor's Choice"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(kicker)
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.editorGold)

                Rectangle()
                    .fill(HCTheme.editorGold.opacity(0.78))
                    .frame(height: HCTheme.hairline)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: HCTheme.featuredImageAspectRatio,
                cornerRadius: 0,
                accessibilityLabel: item.title
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(item.displayTitle)
                    .font(.cultureTitle(31))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.hook)
                    .font(.body)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Creator: \(item.creatorDisplay)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.cardMetadataDisplay)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(HCTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.editorGold.opacity(0.72), lineWidth: 1.4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius - 2, style: .continuous)
                .stroke(HCTheme.line.opacity(0.45), lineWidth: HCTheme.hairline)
                .padding(3)
        }
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }
}
