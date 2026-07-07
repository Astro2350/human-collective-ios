import SwiftUI
import UIKit

struct ZoomableImageViewer: View {
    let imageURL: String
    let title: String
    let onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isZoomed = false
    @State private var isLoading = true
    @State private var didFail = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                ZoomableRemoteImage(
                    url: CultureAsyncImage.normalizedImageURL(from: imageURL),
                    isZoomed: $isZoomed,
                    isLoading: $isLoading,
                    didFail: $didFail
                )
                    .ignoresSafeArea()
                    .accessibilityLabel(title)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Loading image")
                } else if didFail {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 30, weight: .light))

                        Text("Couldn't load this image.")
                            .font(.headline)

                        Text("Check your connection and try again.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(28)
                    .accessibilityElement(children: .combine)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.48), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.22), lineWidth: 0.75)
                        }
                }
                .padding(.top, max(proxy.safeAreaInsets.top + 10, 18))
                .padding(.trailing, 18)
                .accessibilityLabel("Close image")
            }
        }
        .offset(y: max(dragOffset.height, 0))
        .opacity(viewerOpacity)
        .background(Color.black.ignoresSafeArea())
        .simultaneousGesture(dismissDrag)
        .accessibilityAction(.escape, onDismiss)
    }

    private var viewerOpacity: Double {
        let progress = min(max(dragOffset.height / 220, 0), 1)
        return 1 - (progress * 0.36)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard !isZoomed else { return }
                guard value.translation.height > 0 else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isZoomed else {
                    dragOffset = .zero
                    return
                }

                let shouldDismiss = value.translation.height > 110 || value.predictedEndTranslation.height > 220

                if shouldDismiss, abs(value.translation.width) < 120 {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onDismiss()
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dragOffset = .zero
                    }
                }
            }
    }
}

private struct ZoomableRemoteImage: UIViewRepresentable {
    let url: URL?
    @Binding var isZoomed: Bool
    @Binding var isLoading: Bool
    @Binding var didFail: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true

        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.isActive = true
        context.coordinator.isZoomed = $isZoomed
        context.coordinator.isLoading = $isLoading
        context.coordinator.didFail = $didFail

        guard context.coordinator.currentURL != url else { return }

        context.coordinator.currentURL = url
        context.coordinator.task?.cancel()
        context.coordinator.imageView?.image = nil
        scrollView.setZoomScale(1, animated: false)
        context.coordinator.updateState(isZoomed: false, isLoading: true, didFail: false)

        guard let url else {
            context.coordinator.updateState(isLoading: false, didFail: true)
            return
        }

        context.coordinator.task = Task {
            do {
                let image = try await CultureImageCache.shared.image(for: url)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard context.coordinator.isActive, !Task.isCancelled else { return }
                    context.coordinator.imageView?.image = image
                    context.coordinator.isLoading?.wrappedValue = false
                    context.coordinator.didFail?.wrappedValue = false
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard context.coordinator.isActive, !Task.isCancelled else { return }
                    context.coordinator.imageView?.image = nil
                    context.coordinator.isLoading?.wrappedValue = false
                    context.coordinator.didFail?.wrappedValue = true
                }
            }
        }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.isActive = false
        coordinator.task?.cancel()
        coordinator.cancelPendingStateUpdate()
        coordinator.imageView?.image = nil
        coordinator.scrollView?.delegate = nil
        coordinator.isZoomed = nil
        coordinator.isLoading = nil
        coordinator.didFail = nil
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        var isActive = true
        var isZoomed: Binding<Bool>?
        var isLoading: Binding<Bool>?
        var didFail: Binding<Bool>?
        var task: Task<Void, Never>?
        var currentURL: URL?
        private var pendingStateUpdate: Task<Void, Never>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard isActive else { return }
            updateState(isZoomed: scrollView.zoomScale > scrollView.minimumZoomScale + 0.01)
        }

        func updateState(
            isZoomed nextIsZoomed: Bool? = nil,
            isLoading nextIsLoading: Bool? = nil,
            didFail nextDidFail: Bool? = nil
        ) {
            pendingStateUpdate?.cancel()
            pendingStateUpdate = Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, self.isActive, !Task.isCancelled else { return }

                if let nextIsZoomed {
                    self.isZoomed?.wrappedValue = nextIsZoomed
                }
                if let nextIsLoading {
                    self.isLoading?.wrappedValue = nextIsLoading
                }
                if let nextDidFail {
                    self.didFail?.wrappedValue = nextDidFail
                }
            }
        }

        func cancelPendingStateUpdate() {
            pendingStateUpdate?.cancel()
            pendingStateUpdate = nil
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let tapPoint = gesture.location(in: imageView)
            let zoomScale = min(scrollView.maximumZoomScale, 2.8)
            let width = scrollView.bounds.width / zoomScale
            let height = scrollView.bounds.height / zoomScale
            let zoomRect = CGRect(
                x: tapPoint.x - width / 2,
                y: tapPoint.y - height / 2,
                width: width,
                height: height
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}
