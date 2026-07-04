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
                        isShowingImageViewer = true
                    } label: {
                        CultureAsyncImage(imageURL: item.imageURL, aspectRatio: HCTheme.detailImageAspectRatio, cornerRadius: 0)
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
        .background(HCTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleSaved()
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave" : "Save")
            }
        }
        .fullScreenCover(isPresented: $isShowingImageViewer) {
            ZoomableImageViewer(imageURL: item.imageURL, title: item.title)
        }
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

    private func factStrip(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(HCTheme.line.opacity(0.7))
                .frame(height: HCTheme.hairline)

            VStack(alignment: .leading, spacing: 12) {
                DetailFact(label: "Origin", value: item.placeDisplay)
                DetailFact(label: "Made", value: item.dateDisplay)
                DetailFact(label: "Maker", value: item.makerDisplay)
            }

            Rectangle()
                .fill(HCTheme.line.opacity(0.7))
                .frame(height: HCTheme.hairline)
        }
    }

    private func actionRow(_ item: CultureItem) -> some View {
        VStack(spacing: 11) {
            Button {
                viewModel.toggleSaved()
            } label: {
                Label(viewModel.isSaved ? "Saved" : "Save", systemImage: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(HCTheme.blueStone)

            HStack(spacing: 11) {
                ShareLink(item: shareText(for: item)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(HCTheme.blueStone)

                if let url = URL(string: item.sourceURL) {
                    Link(destination: url) {
                        Label("Source", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(HCTheme.blueStone)
                } else {
                    Button {} label: {
                        Label("Source", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(HCTheme.blueStone)
                    .disabled(true)
                }
            }
        }
    }

    private func storySection(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Story")
                .font(.cultureKicker())
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)

            Text(item.story)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func whyItMattersSection(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Why it matters")
                .font(.cultureKicker())
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)

            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(HCTheme.clay.opacity(0.75))
                    .frame(width: 2)

                Text(item.whyItMatters)
                    .font(.cultureTitle(21, weight: .regular))
                    .foregroundStyle(HCTheme.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
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

            Text("\(item.sourceName). \(item.license).")
                .font(.footnote)
                .foregroundStyle(HCTheme.mutedInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareText(for item: CultureItem) -> String {
        "\(item.title) - \(item.placeDisplay). Source: \(item.sourceURL)"
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
