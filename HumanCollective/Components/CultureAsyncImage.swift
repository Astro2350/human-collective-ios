import SwiftUI
import UIKit

struct CultureAsyncImage: View {
    let imageURL: String
    var aspectRatio: CGFloat = HCTheme.feedImageAspectRatio
    var cornerRadius: CGFloat = HCTheme.cardRadius
    var accessibilityLabel: String?

    @State private var phase: CultureImagePhase = .idle

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HCTheme.surfaceDeep

                switch phase {
                case .idle, .loading:
                    ImageLoadingPlaceholder()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                case .success(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                case .failure:
                    placeholder
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(HCTheme.line.opacity(0.48), lineWidth: HCTheme.hairline)
            }
            .clipped()
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "Culture image")
        .task(id: resolvedURL) {
            await loadImage(from: resolvedURL)
        }
    }

    @MainActor
    private func loadImage(from url: URL?) async {
        guard let url else {
            phase = .failure
            return
        }

        if let cachedData = await CultureImageCache.shared.cachedData(for: url),
           let image = UIImage(data: cachedData) {
            phase = .success(image)
            return
        }

        if case .success = phase {
            phase = .loading
        } else if case .idle = phase {
            phase = .loading
        }

        do {
            let data = try await CultureImageCache.shared.data(for: url)
            guard !Task.isCancelled, let image = UIImage(data: data) else { return }

            withAnimation(.easeInOut(duration: 0.24)) {
                phase = .success(image)
            }
        } catch is CancellationError {
            return
        } catch {
            withAnimation(.easeInOut(duration: 0.18)) {
                phase = .failure
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 30, weight: .light))
            .foregroundStyle(HCTheme.secondaryInk.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedURL: URL? {
        Self.normalizedImageURL(from: imageURL)
    }

    static func normalizedImageURL(from imageURL: String) -> URL? {
        guard let url = URL(string: imageURL) else { return nil }

        let marker = "/wikipedia/commons/thumb/"
        guard imageURL.contains("upload.wikimedia.org"),
              let range = imageURL.range(of: marker) else {
            return url
        }

        let remainder = imageURL[range.upperBound...]
        let pathParts = remainder.split(separator: "/")
        guard pathParts.count >= 3 else { return url }

        let fileName = pathParts[2]
        let redirectURL = "https://commons.wikimedia.org/wiki/Special:Redirect/file/\(fileName)?width=900"
        return URL(string: redirectURL) ?? url
    }
}

private enum CultureImagePhase {
    case idle
    case loading
    case success(UIImage)
    case failure
}

private struct ImageLoadingPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        Rectangle()
            .fill(HCTheme.surfaceDeep.opacity(isDimmed ? 0.68 : 1))
            .overlay {
                LinearGradient(
                    colors: [
                        .white.opacity(0.05),
                        .white.opacity(0.18),
                        .white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .task {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}
