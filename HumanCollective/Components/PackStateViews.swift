import SwiftUI

struct CultureLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(HCTheme.secondaryInk)
            Text("Preparing this week's pack")
                .font(.callout)
                .foregroundStyle(HCTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCTheme.background)
    }
}

struct CultureEmptyStateView: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Rectangle()
                    .fill(HCTheme.line.opacity(0.75))
                    .frame(width: 42, height: HCTheme.hairline)

                Image(systemName: "bookmark")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(HCTheme.mutedInk)
                    .frame(width: 72, height: 72)
                    .background(HCTheme.surface, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(HCTheme.line.opacity(0.6), lineWidth: HCTheme.hairline)
                    }
            }

            Text(title)
                .font(.cultureTitle(28))
                .foregroundStyle(HCTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 42)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCTheme.background)
    }
}

struct CultureErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(HCTheme.clay)

            Text("Something did not load")
                .font(.cultureTitle(28))
                .foregroundStyle(HCTheme.ink)

            Text(message)
                .font(.callout)
                .foregroundStyle(HCTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button(action: retry) {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(HCTheme.blueStone)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCTheme.background)
    }
}
