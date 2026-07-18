import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    let title: String
    private let trailing: Trailing

    init(_ title: String) where Trailing == EmptyView {
        self.title = title
        self.trailing = EmptyView()
    }

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.cultureTitle(HCTheme.screenTitleSize))
                    .foregroundStyle(HCTheme.ink)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)

                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(HCTheme.line.opacity(0.75))
                .frame(height: HCTheme.hairline)
        }
        .padding(.top, HCTheme.screenTopPadding)
    }
}

struct FloatingCircleLabel: View {
    let systemName: String
    let foregroundColor: Color
    let backgroundColor: Color
    var showsBorder = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: HCTheme.floatingControlSize, height: HCTheme.floatingControlSize)
            .background(backgroundColor, in: Circle())
            .overlay {
                if showsBorder {
                    Circle()
                        .stroke(HCTheme.line.opacity(0.7), lineWidth: HCTheme.hairline)
                }
            }
            .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
    }
}
