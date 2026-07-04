import SwiftUI
import UIKit

struct GuidedCultureImageView: View {
    let item: CultureItem
    let scene: GuidedCultureScene
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var didFail = false

    var body: some View {
        GeometryReader { proxy in
            Button(action: onTap) {
                ZStack {
                    HCTheme.surfaceDeep

                    if let image {
                        transformedImage(image, in: proxy.size)
                    } else if didFail {
                        imageFailure
                    } else {
                        ProgressView()
                            .tint(HCTheme.secondaryInk)
                    }

                    if let callout = scene.callout {
                        calloutLabel(callout, in: proxy.size)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: HCTheme.hairline)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open image viewer for \(item.title)")
            .accessibilityHint("Opens the zoomable image viewer")
        }
        .task(id: resolvedURL) {
            await loadImage()
        }
    }

    private func transformedImage(_ image: UIImage, in size: CGSize) -> some View {
        let zoom = CGFloat(max(scene.zoom, 1))
        let offset = offset(for: size, zoom: zoom)

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)

            highlight(in: size)
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(zoom)
        .offset(offset)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.62), value: scene.id)
    }

    @ViewBuilder
    private func highlight(in size: CGSize) -> some View {
        if let x = scene.highlightX,
           let y = scene.highlightY,
           let radius = scene.highlightRadius {
            let diameter = max(min(size.width, size.height) * CGFloat(radius), 34)

            Circle()
                .stroke(.white.opacity(0.86), lineWidth: 1.5)
                .background(Circle().fill(HCTheme.editorGold.opacity(0.16)))
                .frame(width: diameter, height: diameter)
                .position(
                    x: clamped(CGFloat(x), 0, 1) * size.width,
                    y: clamped(CGFloat(y), 0, 1) * size.height
                )
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                .accessibilityHidden(true)
        }
    }

    private func calloutLabel(_ text: String, in size: CGSize) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.black.opacity(0.54), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: HCTheme.hairline)
            }
            .frame(maxWidth: max(size.width - 36, 120), alignment: .leading)
            .position(
                x: calloutX(in: size),
                y: max(size.height - 30, 30)
            )
            .accessibilityLabel(text)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: scene.id)
    }

    private var imageFailure: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .light))

            Text("Image unavailable")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(HCTheme.secondaryInk.opacity(0.78))
        .multilineTextAlignment(.center)
        .padding(18)
    }

    @MainActor
    private func loadImage() async {
        guard let url = resolvedURL else {
            isLoading = false
            didFail = true
            return
        }

        if let cachedData = await CultureImageCache.shared.cachedData(for: url),
           let cachedImage = UIImage(data: cachedData) {
            image = cachedImage
            isLoading = false
            didFail = false
            return
        }

        isLoading = true
        didFail = false

        do {
            let data = try await CultureImageCache.shared.data(for: url)
            guard !Task.isCancelled, let loadedImage = UIImage(data: data) else { return }
            image = loadedImage
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            isLoading = false
            didFail = true
        }
    }

    private var resolvedURL: URL? {
        CultureAsyncImage.normalizedImageURL(from: scene.imageURLOverride ?? item.imageURL)
    }

    private func offset(for size: CGSize, zoom: CGFloat) -> CGSize {
        let focusX = clamped(CGFloat(scene.focusX), 0, 1)
        let focusY = clamped(CGFloat(scene.focusY), 0, 1)
        let multiplier = max(zoom - 1, 0)

        return CGSize(
            width: (0.5 - focusX) * size.width * multiplier,
            height: (0.5 - focusY) * size.height * multiplier
        )
    }

    private func calloutX(in size: CGSize) -> CGFloat {
        let x = CGFloat(scene.highlightX ?? scene.focusX)
        return clamped(x, 0.24, 0.76) * size.width
    }

    private func clamped(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
