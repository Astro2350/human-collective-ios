import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selection = 0

    private let pages = [
        OnboardingPage(
            title: "A weekly pause for human culture.",
            subtitle: "A calmer way to meet the things people have made.",
            symbolName: "sun.horizon"
        ),
        OnboardingPage(
            title: "Artifacts, artworks, objects, places, and stories from around the world.",
            subtitle: "A small pack, intentionally gathered.",
            symbolName: "globe.europe.africa"
        ),
        OnboardingPage(
            title: "No feed. No likes. Just one thoughtful culture pack each week.",
            subtitle: "Open it like a museum booklet.",
            symbolName: "book.closed"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Button(action: advance) {
                HStack {
                    Text(selection == pages.count - 1 ? "Start exploring" : "Continue")
                    Image(systemName: selection == pages.count - 1 ? "arrow.right" : "chevron.right")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(HCTheme.blueStone)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
            .padding(HCTheme.pagePadding)
        }
        .background(HCTheme.background.ignoresSafeArea())
    }

    private func advance() {
        if selection == pages.count - 1 {
            onComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                selection += 1
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let symbolName: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 40)

            Image(systemName: page.symbolName)
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(HCTheme.moss)
                .frame(width: 96, height: 96)
                .background(HCTheme.surface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(HCTheme.line.opacity(0.6), lineWidth: 1)
                }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.cultureTitle(36))
                    .foregroundStyle(HCTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 100)
        }
    }
}
