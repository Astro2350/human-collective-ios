import MapKit
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

                    VStack(alignment: .leading, spacing: 26) {
                        articleHeader(item)
                        actionRow(item)
                        highlightsSection(item)
                        contextSection(item)
                        meaningSection(item)
                        summarySection(item)
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

    private func actionRow(_ item: CultureItem) -> some View {
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

    @ViewBuilder
    private func contextSection(_ item: CultureItem) -> some View {
        let date = cleanedText(item.dateDisplay)
        let place = cleanedText(item.placeDisplay)
        let coordinate = coordinate(for: item)

        if date != nil || (place != nil && coordinate != nil) {
            DetailSection(title: "Timeline and map", systemImage: "map") {
                VStack(alignment: .leading, spacing: 18) {
                    if let date {
                        ContextValueRow(label: "Source date", value: date)
                        TimelineStrip(placement: timelinePlacement(for: date))
                    }

                    if let place, let coordinate {
                        ContextValueRow(label: "Origin", value: place)
                        OriginMapView(coordinate: coordinate)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func highlightsSection(_ item: CultureItem) -> some View {
        let highlights = highlightTexts(for: item)

        if !highlights.isEmpty {
            DetailSection(title: "Look first", systemImage: "list.bullet") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                        HighlightRow(index: index + 1, text: highlight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ item: CultureItem) -> some View {
        let paragraphs = summaryParagraphs(for: item)

        if !paragraphs.isEmpty {
            DetailSection(title: "Detailed Summary", systemImage: "text.alignleft") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.body)
                            .foregroundStyle(HCTheme.secondaryInk)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func meaningSection(_ item: CultureItem) -> some View {
        let insights = meaningInsights(for: item)

        if !insights.isEmpty {
            DetailSection(title: "Meaning", systemImage: "sparkle") {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(insights) { insight in
                        InsightBlock(label: insight.label, text: insight.text, accent: insight.accent)
                    }
                }
            }
        }
    }

    private func sourceSection(_ item: CultureItem) -> some View {
        DetailSection(title: "Source and license", systemImage: "link") {
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

    private func highlightTexts(for item: CultureItem) -> [String] {
        var highlights: [String] = []

        for sentence in sentences(from: item.story).prefix(2) {
            highlights.append(highlightSnippet(from: sentence))
        }

        if let maker = cleanedText(item.maker) {
            highlights.append("Made by \(maker).")
        }

        if highlights.isEmpty, let hook = cleanedText(item.hook) {
            highlights.append(hook)
        }

        if highlights.isEmpty {
            highlights.append("\(item.category.displayName) selected for close reading.")
        }

        return Array(highlights.prefix(4))
    }

    private func highlightSnippet(from sentence: String) -> String {
        let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 150,
              let separator = cleaned.firstIndex(of: ":") else {
            return cleaned
        }

        let suffix = cleaned[cleaned.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard suffix.count >= 40 else { return cleaned }

        return capitalizedFirstLetter(suffix)
    }

    private func capitalizedFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + String(text.dropFirst())
    }

    private func summaryParagraphs(for item: CultureItem) -> [String] {
        guard let story = cleanedText(item.story) else { return [] }

        let storySentences = sentences(from: story)
        guard !storySentences.isEmpty else { return [story] }

        return stride(from: 0, to: storySentences.count, by: 2).map { index in
            let endIndex = min(index + 2, storySentences.count)
            return storySentences[index..<endIndex].joined(separator: " ")
        }
    }

    private func meaningInsights(for item: CultureItem) -> [MeaningInsight] {
        var insights: [MeaningInsight] = []

        if let whyItMatters = cleanedText(item.whyItMatters) {
            insights.append(MeaningInsight(label: "Why it matters", text: whyItMatters, accent: HCTheme.clay))
        }

        let category = item.category.displayName.lowercased()
        let significance = "This \(category) turns material, form, and use into evidence, making a larger cultural world easier to study through one concrete example."
        insights.append(MeaningInsight(label: "Significance", text: significance, accent: HCTheme.moss))

        return insights
    }

    private func timelinePlacement(for dateDisplay: String) -> TimelinePlacement? {
        let lowercase = dateDisplay.lowercased()
        let numbers = numbers(in: dateDisplay)
        guard !numbers.isEmpty else { return nil }

        let isBCE = lowercase.contains("bce") || lowercase.contains("bc")
        let isCentury = lowercase.contains("century")
        let years = numbers.map { number -> Double in
            if isCentury {
                let midpoint = (Double(number - 1) * 100) + 50
                return isBCE ? -midpoint : midpoint
            }

            return isBCE ? -Double(number) : Double(number)
        }

        let averageYear = years.reduce(0, +) / Double(years.count)
        return TimelinePlacement(year: averageYear)
    }

    private func numbers(in text: String) -> [Int] {
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, range: range).compactMap { match in
            Int(nsText.substring(with: match.range))
        }
    }

    private func coordinate(for item: CultureItem) -> CLLocationCoordinate2D? {
        guard let latitude = item.latitude,
              let longitude = item.longitude,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func sentences(from text: String) -> [String] {
        guard let text = cleanedText(text) else { return [] }

        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.bySentences, .localized]) { sentence, _, _, _ in
            if let sentence, let cleaned = cleanedText(sentence) {
                sentences.append(cleaned)
            }
        }

        return sentences
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

private struct TimelinePlacement {
    let year: Double
}

private struct MeaningInsight: Identifiable {
    let label: String
    let text: String
    let accent: Color

    var id: String {
        label
    }
}

private struct ContextValueRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.cultureKicker(10))
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.mutedInk)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HCTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimelineStrip: View {
    let placement: TimelinePlacement?

    private let minYear = -2200.0
    private let maxYear = 2026.0

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                let markerSize: CGFloat = 11
                let width = proxy.size.width
                let markerX = markerOffset(width: width, markerSize: markerSize)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(HCTheme.line.opacity(0.72))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)

                    if placement != nil {
                        Circle()
                            .fill(HCTheme.clay)
                            .frame(width: markerSize, height: markerSize)
                            .offset(x: markerX)
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            .accessibilityHidden(true)

            HStack {
                Text("BCE")
                Spacer()
                Text("CE")
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(HCTheme.mutedInk)
        }
    }

    private func markerOffset(width: CGFloat, markerSize: CGFloat) -> CGFloat {
        guard let placement else { return 0 }

        let clampedYear = min(max(placement.year, minYear), maxYear)
        let progress = (clampedYear - minYear) / (maxYear - minYear)
        let availableWidth = max(width - markerSize, 0)

        return availableWidth * CGFloat(progress)
    }
}

private struct OriginMapView: View {
    let coordinate: CLLocationCoordinate2D

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            Annotation("", coordinate: coordinate) {
                Circle()
                    .fill(HCTheme.clay)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(HCTheme.surface, lineWidth: 3)
                    }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .allowsHitTesting(false)
        .frame(height: 146)
        .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let systemImage: String?
    private let content: Content

    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Rectangle()
                .fill(HCTheme.line.opacity(0.55))
                .frame(height: HCTheme.hairline)

            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HCTheme.clay)
                }

                Text(title)
                    .font(.cultureKicker())
                    .textCase(.uppercase)
                    .foregroundStyle(HCTheme.clay)

                Spacer(minLength: 0)
            }

            content
        }
    }
}

private struct HighlightRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.caption2.weight(.bold))
                .foregroundStyle(HCTheme.clay)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 3)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InsightBlock: View {
    let label: String
    let text: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.cultureKicker(10))
                .textCase(.uppercase)
                .foregroundStyle(accent)

            HStack(alignment: .top, spacing: 13) {
                Rectangle()
                    .fill(accent.opacity(0.72))
                    .frame(width: 2)

                Text(text)
                    .font(.body)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
