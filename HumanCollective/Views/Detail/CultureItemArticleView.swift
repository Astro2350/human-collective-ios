import MapKit
import SwiftUI

struct CultureItemArticleView: View {
    private static let numberRegex = try? NSRegularExpression(pattern: #"\d+"#)

    let item: CultureItem
    var isSaved = false
    var showsSaveAction = false
    var imageHorizontalPadding: CGFloat = 0
    var imageCornerRadius: CGFloat = 0
    var imageUsesNaturalAspectRatio = false
    var imageMinimumAspectRatio: CGFloat?
    var contentBottomPadding: CGFloat = 42
    var onToggleSaved: (() -> Void)?

    @State private var isShowingImageViewer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageButton
                .padding(.horizontal, imageHorizontalPadding)

            VStack(alignment: .leading, spacing: 26) {
                articleHeader(item)
                actionRow(item)
                contextSection(item)
                meaningSection(item)
                deepDiveSection(item)
                sourceSection(item)
            }
            .padding(.horizontal, HCTheme.pagePadding)
            .padding(.top, 24)
            .padding(.bottom, contentBottomPadding)
        }
        .background(HCTheme.background)
        .fullScreenCover(isPresented: $isShowingImageViewer) {
            ZoomableImageViewer(imageURL: item.imageURL, title: item.title) {
                isShowingImageViewer = false
            }
            .ignoresSafeArea()
            .presentationBackground(.black)
            .statusBarHidden(true)
        }
    }

    private var imageButton: some View {
        Button {
            isShowingImageViewer = true
        } label: {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: HCTheme.detailImageAspectRatio,
                usesNaturalAspectRatio: imageUsesNaturalAspectRatio,
                minimumAspectRatio: imageMinimumAspectRatio,
                cornerRadius: imageCornerRadius,
                accessibilityLabel: item.title
            )
            .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
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
    }

    private func articleHeader(_ item: CultureItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.displayTitle)
                .font(.cultureTitle(42))
                .foregroundStyle(HCTheme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let hook = cleanedText(item.hook) {
                Text(hook)
                    .font(.cultureTitle(21, weight: .regular))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CreatorAttributionView(creator: item.creatorDisplay)
        }
    }

    @ViewBuilder
    private func actionRow(_ item: CultureItem) -> some View {
        if showsSaveAction, let onToggleSaved {
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onToggleSaved()
                    }
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(HCTheme.blueStone)
                .accessibilityLabel(isSaved ? "Unsave" : "Save")

                shareAndSourceRow(item)
            }
        } else {
            shareAndSourceRow(item)
        }
    }

    private func shareAndSourceRow(_ item: CultureItem) -> some View {
        HStack(spacing: 10) {
            ShareLink(item: shareText(for: item)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(HCTheme.blueStone)

            sourceButton(item)
        }
    }

    @ViewBuilder
    private func sourceButton(_ item: CultureItem) -> some View {
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

    @ViewBuilder
    private func contextSection(_ item: CultureItem) -> some View {
        let date = cleanedText(item.dateDisplay)
        let place = cleanedText(item.placeDisplay)
        let coordinate = coordinate(for: item)

        if date != nil || (place != nil && coordinate != nil) {
            DetailSection(title: "Timeline and map", systemImage: "map") {
                VStack(alignment: .leading, spacing: 18) {
                    if let date {
                        ContextValueRow(label: "Date", value: date)
                        TimelineStrip(placement: timelinePlacement(for: date))
                    }

                    if let place, let coordinate {
                        OriginMapView(coordinate: coordinate)

                        Label(place, systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HCTheme.secondaryInk)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func meaningSection(_ item: CultureItem) -> some View {
        if let whyItMatters = cleanedText(item.whyItMatters) {
            DetailSection(title: "Significance", systemImage: "sparkle") {
                PullQuoteBlock(text: whyItMatters, accent: HCTheme.clay)
            }
        }
    }

    @ViewBuilder
    private func deepDiveSection(_ item: CultureItem) -> some View {
        let paragraphs = storyParagraphs(for: item)

        if !paragraphs.isEmpty {
            DetailSection(title: "Deep dive", systemImage: "text.alignleft") {
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

    private func sourceSection(_ item: CultureItem) -> some View {
        DetailSection(title: "Source", systemImage: "link") {
            Text(sourceSummary(for: item))
                .font(.footnote)
                .foregroundStyle(HCTheme.mutedInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareText(for item: CultureItem) -> String {
        var parts = [item.title]
        parts.append("Creator: \(item.creatorDisplay)")
        if let place = cleanedText(item.placeDisplay) {
            parts.append(place)
        }
        if let sourceURL = cleanedURLString(item.sourceURL) {
            parts.append("Source: \(sourceURL)")
        }
        return parts.joined(separator: " - ")
    }

    private func storyParagraphs(for item: CultureItem) -> [String] {
        guard let story = cleanedText(item.story) else { return [] }

        let storySentences = sentences(from: story)
        guard !storySentences.isEmpty else { return [story] }

        return stride(from: 0, to: storySentences.count, by: 2).map { index in
            let endIndex = min(index + 2, storySentences.count)
            return storySentences[index..<endIndex].joined(separator: " ")
        }
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
        guard let regex = Self.numberRegex else { return [] }

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
        let license = cleanedLicense(item.license)

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
              lowercase != "creator unknown",
              lowercase != "date unknown",
              lowercase != "source unknown",
              lowercase != "license unknown" else {
            return nil
        }

        return cleaned
    }

    private func cleanedLicense(_ value: String?) -> String? {
        guard let license = cleanedText(value) else { return nil }

        if let noteRange = license.range(of: "; verify", options: .caseInsensitive) {
            return license[..<noteRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return license
    }
}

private struct TimelinePlacement {
    let year: Double
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

private struct CreatorAttributionView: View {
    let creator: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("Creator")
                .font(.cultureKicker(10))
                .textCase(.uppercase)
                .foregroundStyle(HCTheme.clay)

            Text(creator)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HCTheme.secondaryInk)
                .lineLimit(2)
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

private struct PullQuoteBlock: View {
    let text: String
    let accent: Color

    var body: some View {
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
        .padding(.vertical, 2)
    }
}
