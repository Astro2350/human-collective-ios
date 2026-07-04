import SwiftUI

struct CategoryChip: View {
    let category: CultureCategory

    var body: some View {
        Text(category.displayName)
            .font(.cultureKicker())
            .textCase(.uppercase)
            .foregroundStyle(HCTheme.secondaryInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(HCTheme.surface.opacity(0.68), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(HCTheme.line.opacity(0.7), lineWidth: HCTheme.hairline)
            }
            .accessibilityLabel(category.displayName)
    }
}
