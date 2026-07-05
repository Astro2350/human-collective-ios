import SwiftUI

struct CultureDetailView: View {
    @State private var viewModel: CultureDetailViewModel
    @State private var isShowingImageViewer = false

    init(item: CultureItem, savedStore: SavedStore) {
        _viewModel = State(initialValue: CultureDetailViewModel(item: item, savedStore: savedStore))
    }

    var body: some View {
        let item = viewModel.item

        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isShowingImageViewer = true
                        }
                    } label: {
                        CultureAsyncImage(
                            imageURL: item.imageURL,
                            aspectRatio: HCTheme.detailImageAspectRatio,
                            cornerRadius: 0,
                            accessibilityLabel: item.title
                        )
                            .clipShape(Rectangle())
                            .overlay(alignment: .bottomLeading) {
                                CategoryChip(category: item.category)
                                    .padding(18)
                            }
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.black.opacity(0.38), in: Circle())
                                    .padding(16)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open image")
                    .accessibilityHint("Opens a full screen viewer with zoom controls")

                    VStack(alignment: .leading, spacing: 28) {
                        articleHeader(item)
                        factStrip(item)
                        actionRow(item)
                        storySection(item)
                        whyItMattersSection(item)
                        sourceSection(item)
                    }
                    .padding(.horizontal, HCTheme.pagePadding)
                    .padding(.top, 24)
                    .padding(.bottom, 42)
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
        }
        .allowsHitTesting(!isShowingImageViewer)
        .accessibilityHidden(isShowingImageViewer)
        .background(HCTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbar(isShowingImageViewer ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(isShowingImageViewer)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.toggleSaved()
                    }
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave" : "Save")
            }
        }
        .overlay {
            if isShowingImageViewer {
                ZoomableImageViewer(imageURL: item.imageURL, title: item.title) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingImageViewer = false
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(10)
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.isSaved)
    }

    private func articleHeader(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.title)
                .font(.cultureTitle(42))
                .foregroundStyle(HCTheme.ink)
                .lineLimit(4)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.hook)
                .font(.cultureTitle(21, weight: .regular))
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func factStrip(_ item: CultureItem) -> some View {
        let facts = detailFacts(for: item)

        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Rectangle()
                    .fill(HCTheme.line.opacity(0.7))
                    .frame(height: HCTheme.hairline)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(facts) { fact in
                        DetailFact(label: fact.label, value: fact.value)
                    }
                }

                Rectangle()
                    .fill(HCTheme.line.opacity(0.7))
                    .frame(height: HCTheme.hairline)
            }
        }
    }

    private func actionRow(_ item: CultureItem) -> some View {
        VStack(spacing: 11) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.toggleSaved()
                }
            } label: {
                Label(viewModel.isSaved ? "Saved" : "Save", systemImage: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                    .frame(maxWidth: .infinity)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(HCTheme.blueStone)

            HStack(spacing: 11) {
                ShareLink(item: shareText(for: item)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(HCTheme.blueStone)

                if let url = sourceURL(for: item) {
                    Link(destination: url) {
                        Label("Source", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(HCTheme.blueStone)
                } else {
                    Button {} label: {
                        Label("Source", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(HCTheme.blueStone)
                    .disabled(true)
                    .accessibilityLabel("Source unavailable")
                }
            }
        }
    }

    @ViewBuilder
    private func storySection(_ item: CultureItem) -> some View {
        if let story = cleanedText(item.story) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Story")
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.clay)

                Text(story)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func whyItMattersSection(_ item: CultureItem) -> some View {
        if let whyItMatters = cleanedText(item.whyItMatters) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Why it matters")
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.clay)

                HStack(alignment: .top, spacing: 14) {
                    Rectangle()
                        .fill(HCTheme.clay.opacity(0.75))
                        .frame(width: 2)

                    Text(whyItMatters)
                        .font(.cultureTitle(21, weight: .regular))
                        .foregroundStyle(HCTheme.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func sourceSection(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(HCTheme.line.opacity(0.7))
                .frame(height: HCTheme.hairline)

            Text("Source and license")
                .font(.cultureKicker())
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)

            Text(sourceSummary(for: item))
                .font(.footnote)
                .foregroundStyle(HCTheme.mutedInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareText(for item: CultureItem) -> String {
        var parts = [item.title]
        if let place = cleanedText(item.placeDisplay) {
            parts.append(place)
        }
        if let sourceURL = cleanedURLString(item.sourceURL) {
            parts.append("Source: \(sourceURL)")
        }
        return parts.joined(separator: " - ")
    }

    private func detailFacts(for item: CultureItem) -> [DetailFactModel] {
        [
            cleanedText(item.placeDisplay).map { DetailFactModel(label: "Origin", value: $0) },
            cleanedText(item.dateDisplay).map { DetailFactModel(label: "Made", value: $0) },
            cleanedText(item.maker).map { DetailFactModel(label: "Maker", value: $0) }
        ]
        .compactMap { $0 }
    }

    private func sourceSummary(for item: CultureItem) -> String {
        let sourceName = cleanedText(item.sourceName)
        let license = cleanedText(item.license)

        switch (sourceName, license) {
        case let (source?, license?):
            return "\(source). \(license)."
        case let (source?, nil):
            return "\(source). License details are not provided."
        case let (nil, license?):
            return "Source archive not provided. \(license)."
        case (nil, nil):
            return "Source and license details are not provided."
        }
    }

    private func cleanedURLString(_ value: String) -> String? {
        guard let cleaned = cleanedText(value), URL(string: cleaned) != nil else { return nil }
        return cleaned
    }

    private func sourceURL(for item: CultureItem) -> URL? {
        guard let cleaned = cleanedText(item.sourceURL),
              let url = URL(string: cleaned),
              url.scheme != nil else {
            return nil
        }

        return url
    }

    private func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let lowercase = cleaned.lowercased()
        guard lowercase != "unknown",
              lowercase != "maker unknown",
              lowercase != "date unknown",
              lowercase != "source unknown",
              lowercase != "license unknown" else {
            return nil
        }

        return cleaned
    }
}

private struct DetailFactModel: Identifiable {
    let label: String
    let value: String

    var id: String {
        label
    }
}

private struct DetailFact: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.cultureKicker())
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.mutedInk)
                .frame(width: 60, alignment: .leading)

            Text(value.isEmpty ? "Unknown" : value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(HCTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
