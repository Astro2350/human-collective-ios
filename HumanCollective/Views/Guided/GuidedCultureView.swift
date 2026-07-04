import SwiftUI

struct GuidedCultureView: View {
    let item: CultureItem
    let guidedScenes: [GuidedCultureScene]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeIndex = 0
    @State private var isShowingImageViewer = false

    private var scenes: [GuidedCultureScene] {
        guidedScenes.sorted { $0.sceneIndex < $1.sceneIndex }
    }

    private var activeScene: GuidedCultureScene {
        let index = min(max(activeIndex, 0), max(scenes.count - 1, 0))
        return scenes[index]
    }

    var body: some View {
        Group {
            if scenes.isEmpty {
                emptyGuidedView
            } else {
                GeometryReader { proxy in
                    let topHeight = topAreaHeight(for: proxy.size)

                    ZStack {
                        guidedBackground.ignoresSafeArea()

                        VStack(spacing: 0) {
                            topArea(topHeight: topHeight, safeTop: proxy.safeAreaInsets.top)

                            sceneScroll
                                .frame(height: max(proxy.size.height - topHeight, 260))
                        }
                    }
                }
            }
        }
        .overlay {
            if isShowingImageViewer, !scenes.isEmpty {
                ZoomableImageViewer(imageURL: activeScene.imageURLOverride ?? item.imageURL, title: item.title) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingImageViewer = false
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .statusBarHidden(isShowingImageViewer)
    }

    private var emptyGuidedView: some View {
        ZStack {
            guidedBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Close Guided View")
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                VStack(spacing: 8) {
                    Text("Guided view unavailable")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("There are no guided moments for this piece yet.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }

    private func topArea(topHeight: CGFloat, safeTop: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.18), lineWidth: HCTheme.hairline)
                        }
                }
                .accessibilityLabel("Close Guided View")

                VStack(alignment: .leading, spacing: 3) {
                    Text("Guided View")
                        .font(.cultureKicker(10))
                        .textCase(.uppercase)
                        .foregroundStyle(HCTheme.editorGold)

                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(activeIndex + 1) / \(scenes.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .accessibilityLabel("Scene \(activeIndex + 1) of \(scenes.count)")
            }
            .padding(.horizontal, 18)
            .padding(.top, safeTop + 8)

            GuidedCultureImageView(item: item, scene: activeScene) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingImageViewer = true
                }
            }
            .frame(height: max(topHeight - safeTop - 68, 210))
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(height: topHeight, alignment: .top)
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(0.96),
                    Color(red: 0.13, green: 0.10, blue: 0.075)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityElement(children: .contain)
    }

    private var sceneScroll: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                        GuidedSceneCard(
                            scene: scene,
                            index: index,
                            totalCount: scenes.count,
                            isActive: index == activeIndex
                        )
                        .background {
                            GeometryReader { cardProxy in
                                Color.clear.preference(
                                    key: GuidedScenePositionKey.self,
                                    value: [index: cardProxy.frame(in: .named("guidedSceneScroll")).midY]
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .coordinateSpace(name: "guidedSceneScroll")
            .onPreferenceChange(GuidedScenePositionKey.self) { positions in
                updateActiveScene(from: positions, viewportHeight: proxy.size.height)
            }
        }
        .background(HCTheme.background)
    }

    private var guidedBackground: Color {
        Color(red: 0.08, green: 0.065, blue: 0.05)
    }

    private func updateActiveScene(from positions: [Int: CGFloat], viewportHeight: CGFloat) {
        guard !positions.isEmpty else { return }

        let targetY = viewportHeight * 0.36
        let nearest = positions.min { left, right in
            abs(left.value - targetY) < abs(right.value - targetY)
        }?.key

        guard let nearest, nearest != activeIndex else { return }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
            activeIndex = nearest
        }
    }

    private func topAreaHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.49, 330), 440)
    }
}
