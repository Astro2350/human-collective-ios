import SwiftUI

struct CultureLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
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
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(HCTheme.mutedInk)

            Text(title)
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCTheme.background)
    }
}

struct CultureErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(HCTheme.clay)

            Text("Something did not load")
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)

            Text(message)
                .font(.callout)
                .foregroundStyle(HCTheme.secondaryInk)
                .multilineTextAlignment(.center)

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
