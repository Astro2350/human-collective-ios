import SwiftUI
import UIKit

struct ZoomableImageViewer: View {
    let imageURL: String
    let title: String
    let onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                ZoomableRemoteImage(url: CultureAsyncImage.normalizedImageURL(from: imageURL))
                    .ignoresSafeArea()
                    .accessibilityLabel(title)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
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
                guard value.translation.height > 0 else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
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
        guard context.coordinator.currentURL != url else { return }

        context.coordinator.currentURL = url
        context.coordinator.task?.cancel()
        context.coordinator.imageView?.image = nil
        scrollView.setZoomScale(1, animated: false)

        guard let url else { return }

        context.coordinator.task = Task {
            do {
                let data = try await CultureImageCache.shared.data(for: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }

                await MainActor.run {
                    context.coordinator.imageView?.image = image
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    context.coordinator.imageView?.image = nil
                }
            }
        }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.task?.cancel()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        var task: Task<Void, Never>?
        var currentURL: URL?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
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
