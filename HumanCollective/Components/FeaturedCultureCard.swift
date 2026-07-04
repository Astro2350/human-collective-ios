import SwiftUI

struct FeaturedCultureCard: View {
    let item: CultureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: HCTheme.featuredImageAspectRatio,
                cornerRadius: 0,
                accessibilityLabel: item.title
            )
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))

                    Text("Editor's Choice")
                        .font(.cultureKicker())
                        .textCase(.uppercase)
                }
                .foregroundStyle(HCTheme.editorGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(HCTheme.surface.opacity(0.9), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(HCTheme.editorGold.opacity(0.45), lineWidth: HCTheme.hairline)
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                CategoryChip(category: item.category)

                Text(item.title)
                    .font(.cultureTitle(31))
                    .foregroundStyle(HCTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.hook)
                    .font(.body)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(4)
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
