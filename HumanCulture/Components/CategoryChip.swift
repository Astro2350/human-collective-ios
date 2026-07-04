import SwiftUI

struct CategoryChip: View {
    let category: CultureCategory

    var body: some View {
        Label(category.displayName, systemImage: category.symbolName)
            .font(.caption.weight(.medium))
            .foregroundStyle(HCTheme.ink)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HCTheme.surfaceDeep.opacity(0.72), in: Capsule())
            .accessibilityLabel(category.displayName)
    }
}

