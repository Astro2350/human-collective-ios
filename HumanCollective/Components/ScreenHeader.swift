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
