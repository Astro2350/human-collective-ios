import SwiftUI

struct CultureLoadingView: View {
    var body: some View {
        LoadingSkeletonView()
    }
}

struct LoadingSkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        skeletonLine(width: min(contentWidth * 0.72, 280), height: 34)
                        skeletonLine(width: min(contentWidth * 0.48, 180), height: 34)

                        Rectangle()
                            .fill(HCTheme.line.opacity(0.55))
                            .frame(height: HCTheme.hairline)
                            .padding(.top, 4)
                    }
                    .padding(.top, 18)

                    skeletonCard(width: contentWidth, imageRatio: HCTheme.featuredImageAspectRatio, titleWidth: 0.78)

                    skeletonLine(width: 118, height: 10)

                    skeletonCard(width: contentWidth, imageRatio: HCTheme.feedImageAspectRatio, titleWidth: 0.64)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, 12)
            }
            .accessibilityLabel("Loading this week's culture pack")
        }
        .background(HCTheme.background)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isDimmed = true
            }
        }
    }

    private func skeletonCard(width: CGFloat, imageRatio: CGFloat, titleWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(HCTheme.surfaceDeep.opacity(isDimmed ? 0.62 : 1))
                .aspectRatio(imageRatio, contentMode: .fit)

            VStack(alignment: .leading, spacing: 12) {
                skeletonLine(width: 82, height: 20)
                    .clipShape(Capsule())
                skeletonLine(width: width * titleWidth, height: 28)
                skeletonLine(width: width * 0.88, height: 14)
                skeletonLine(width: width * 0.52, height: 14)
            }
            .padding(16)
        }
        .frame(width: width, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.45), lineWidth: HCTheme.hairline)
        }
        .accessibilityHidden(true)
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: min(height / 2, 6), style: .continuous)
            .fill(HCTheme.surfaceDeep.opacity(isDimmed ? 0.5 : 0.78))
            .frame(width: width, height: height)
    }
}

struct CultureEmptyStateView: View {
    let title: String
    var subtitle: String?
    var systemImage: String = "bookmark"

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Rectangle()
                    .fill(HCTheme.line.opacity(0.75))
                    .frame(width: 42, height: HCTheme.hairline)

                Image(systemName: systemImage)
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
                .fixedSize(horizontal: false, vertical: true)

            Button(action: retry) {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(HCTheme.blueStone)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCTheme.background)
    }
}
