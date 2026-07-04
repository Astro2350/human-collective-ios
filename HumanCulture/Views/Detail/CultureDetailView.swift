import SwiftUI

struct CultureDetailView: View {
    @State private var viewModel: CultureDetailViewModel

    init(item: CultureItem, savedStore: SavedStore) {
        _viewModel = State(initialValue: CultureDetailViewModel(item: item, savedStore: savedStore))
    }

    var body: some View {
        let item = viewModel.item

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                CultureAsyncImage(imageURL: item.imageURL, aspectRatio: 1.02, cornerRadius: 0)
                    .clipShape(Rectangle())
                    .overlay(alignment: .bottomLeading) {
                        CategoryChip(category: item.category)
                            .padding(14)
                    }

                VStack(alignment: .leading, spacing: 22) {
                    titleSection(item)
                    actionRow(item)
                    Divider().overlay(HCTheme.line)
                    storySection(item)
                    whyItMattersSection(item)
                    sourceSection(item)
                }
                .padding(.horizontal, HCTheme.pagePadding)
                .padding(.bottom, 34)
            }
        }
        .background(HCTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
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
    }

    private func titleSection(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.cultureTitle(38))
                .foregroundStyle(HCTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                DetailMetaLine(label: "Place", value: item.placeDisplay)
                DetailMetaLine(label: "Date", value: item.dateDisplay)
                DetailMetaLine(label: "Maker", value: item.makerDisplay)
                DetailMetaLine(label: "Source", value: item.sourceName)
                DetailMetaLine(label: "License", value: item.license)
            }
        }
    }

    private func actionRow(_ item: CultureItem) -> some View {
        VStack(spacing: 10) {
            Button {
                viewModel.toggleSaved()
            } label: {
                Label(viewModel.isSaved ? "Saved" : "Save", systemImage: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(HCTheme.blueStone)

            HStack(spacing: 10) {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Story")
                .font(.headline)
                .foregroundStyle(HCTheme.ink)

            Text(item.story)
                .font(.body)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func whyItMattersSection(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why it matters")
                .font(.headline)
                .foregroundStyle(HCTheme.ink)

            Text(item.whyItMatters)
                .font(.body.weight(.medium))
                .foregroundStyle(HCTheme.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                        .stroke(HCTheme.line.opacity(0.55), lineWidth: 1)
                }
        }
    }

    private func sourceSection(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)
                .foregroundStyle(HCTheme.ink)

            Text("\(item.sourceName) - \(item.license)")
                .font(.callout)
                .foregroundStyle(HCTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareText(for item: CultureItem) -> String {
        "\(item.title) - \(item.placeDisplay). Source: \(item.sourceURL)"
    }
}

private struct DetailMetaLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(HCTheme.mutedInk)
                .frame(width: 58, alignment: .leading)

            Text(value.isEmpty ? "Unknown" : value)
                .font(.subheadline)
                .foregroundStyle(HCTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
