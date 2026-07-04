import SwiftUI

struct GuidedSceneCard: View {
    let scene: GuidedCultureScene
    let index: Int
    let totalCount: Int
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Text(counterText)
                    .font(.cultureKicker(10))
                    .textCase(.uppercase)
                    .foregroundStyle(isActive ? HCTheme.editorGold : HCTheme.mutedInk)

                Rectangle()
                    .fill((isActive ? HCTheme.editorGold : HCTheme.line).opacity(0.62))
                    .frame(height: HCTheme.hairline)
            }

            Text(scene.title)
                .font(.cultureTitle(25))
                .foregroundStyle(HCTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(scene.body)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke((isActive ? HCTheme.editorGold : HCTheme.line).opacity(isActive ? 0.78 : 0.5), lineWidth: isActive ? 1.1 : HCTheme.hairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(counterText). \(scene.title). \(scene.body)")
    }

    private var counterText: String {
        String(format: "%02d / %02d", index + 1, totalCount)
    }
}
