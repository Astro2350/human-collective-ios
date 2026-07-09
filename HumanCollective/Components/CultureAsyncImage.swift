import SwiftUI
import UIKit

struct CultureAsyncImage: View {
    let imageURL: String
    var aspectRatio: CGFloat = HCTheme.feedImageAspectRatio
    var usesNaturalAspectRatio = false
    var minimumAspectRatio: CGFloat?
    var cornerRadius: CGFloat = HCTheme.cardRadius
    var accessibilityLabel: String?

    @State private var phase: CultureImagePhase = .idle
    @State private var isTakingLonger = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HCTheme.surfaceDeep

                switch phase {
                case .idle, .loading:
                    ImageLoadingPlaceholder()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay {
                            if isTakingLonger {
                                slowLoadingMessage
                                    .transition(.opacity)
                            }
                        }
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
        .aspectRatio(resolvedAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "Culture image")
        .task(id: resolvedURL) {
            await loadImage(from: resolvedURL)
        }
        .task(id: phase.isLoading) {
            guard phase.isLoading else {
                isTakingLonger = false
                return
            }

            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, phase.isLoading else { return }

            withAnimation(.easeInOut(duration: 0.18)) {
                isTakingLonger = true
            }
        }
    }

    @MainActor
    private func loadImage(from url: URL?) async {
        guard let url else {
            phase = .failure
            isTakingLonger = false
            return
        }

        if let image = await CultureImageCache.shared.cachedImage(for: url) {
            phase = .success(image)
            isTakingLonger = false
            return
        }

        if case .success = phase {
            phase = .loading
        } else if case .idle = phase {
            phase = .loading
        }

        do {
            let image = try await CultureImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.24)) {
                phase = .success(image)
                isTakingLonger = false
            }
        } catch is CancellationError {
            return
        } catch {
            withAnimation(.easeInOut(duration: 0.18)) {
                phase = .failure
                isTakingLonger = false
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [
                HCTheme.surfaceDeep,
                HCTheme.surfaceRaised.opacity(0.84),
                HCTheme.surfaceDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var slowLoadingMessage: some View {
        Text("This image is taking a little longer than usual.")
            .font(.caption.weight(.medium))
            .foregroundStyle(HCTheme.secondaryInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(HCTheme.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedURL: URL? {
        Self.normalizedImageURL(from: imageURL)
    }

    private var resolvedAspectRatio: CGFloat {
        let baseAspectRatio: CGFloat
        if usesNaturalAspectRatio {
            baseAspectRatio = phase.naturalAspectRatio ?? minimumAspectRatio ?? aspectRatio
        } else {
            baseAspectRatio = aspectRatio
        }

        guard let minimumAspectRatio else { return baseAspectRatio }
        return max(baseAspectRatio, minimumAspectRatio)
    }

    static func normalizedImageURL(from imageURL: String) -> URL? {
        let trimmedURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        return URL(string: trimmedURL)
    }
}

private enum CultureImagePhase {
    case idle
    case loading
    case success(UIImage)
    case failure

    var isLoading: Bool {
        switch self {
        case .idle, .loading:
            true
        case .success, .failure:
            false
        }
    }

    var naturalAspectRatio: CGFloat? {
        guard case .success(let image) = self, image.size.height > 0 else {
            return nil
        }

        return image.size.width / image.size.height
    }
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
