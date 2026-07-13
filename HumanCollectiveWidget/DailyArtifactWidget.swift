import SwiftUI
import UIKit
import WidgetKit

struct DailyArtifactEntry: TimelineEntry {
    let date: Date
    let artifact: WidgetArtifact?
    let imageData: Data?
    let errorMessage: String?
}

struct DailyArtifactProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyArtifactEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyArtifactEntry) -> Void) {
        guard !context.isPreview else {
            completion(.preview)
            return
        }

        Task {
            completion(await loadEntry(for: context.family))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyArtifactEntry>) -> Void) {
        Task {
            let entry = await loadEntry(for: context.family)
            let loadedImageAndTitle = entry.artifact != nil && entry.imageData != nil
            completion(Timeline(entries: [entry], policy: .after(Self.nextRefreshDate(loadSucceeded: loadedImageAndTitle))))
        }
    }

    private func loadEntry(for family: WidgetFamily) async -> DailyArtifactEntry {
        do {
            let artifact = try await WidgetArtifactLoader.loadToday()
            do {
                let maximumImageDimension: CGFloat = family == .accessoryRectangular ? 320 : 900
                let imageData = try await WidgetArtifactLoader.loadImageData(
                    from: artifact.imageURL,
                    maximumDimension: maximumImageDimension
                )
                return DailyArtifactEntry(date: Date(), artifact: artifact, imageData: imageData, errorMessage: nil)
            } catch {
                return DailyArtifactEntry(
                    date: Date(),
                    artifact: artifact,
                    imageData: nil,
                    errorMessage: error.localizedDescription
                )
            }
        } catch {
            return DailyArtifactEntry(
                date: Date(),
                artifact: nil,
                imageData: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    private static func nextRefreshDate(loadSucceeded: Bool) -> Date {
        guard loadSucceeded else {
            return Date().addingTimeInterval(15 * 60)
        }

        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date().addingTimeInterval(3600)
        return calendar.date(byAdding: .minute, value: 5, to: tomorrow) ?? tomorrow
    }
}

struct DailyArtifactWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: DailyArtifactEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rectangularView
            default:
                homeScreenView
            }
        }
        .widgetURL(URL(string: "humancollective://today"))
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.075, blue: 0.065)
        }
    }

    private var homeScreenView: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let data = entry.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.34, green: 0.43, blue: 0.43), Color(red: 0.11, green: 0.10, blue: 0.09)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.18), .black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("HUMAN COLLECTIVE")
                        .font(.system(size: family == .systemSmall ? 8 : 9, weight: .bold))
                        .tracking(1.25)
                        .foregroundStyle(.white.opacity(0.74))

                    Text(entry.artifact?.title ?? "Today's artifact")
                        .font(.system(size: family == .systemSmall ? 18 : 24, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(family == .systemSmall ? 4 : 3)
                        .minimumScaleFactor(0.58)
                        .allowsTightening(true)

                    if family != .systemSmall, let detail = entry.artifact?.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(family == .systemSmall ? 14 : 18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rectangularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            HStack(spacing: 8) {
                Group {
                    if let data = entry.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .grayscale(renderingMode == .fullColor ? 0 : 1)
                            .contrast(renderingMode == .fullColor ? 1 : 1.18)
                    } else {
                        Image(systemName: "photo")
                            .font(.headline)
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.primary.opacity(0.18), lineWidth: 0.5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("HUMAN COLLECTIVE")
                        .font(.system(size: 7.5, weight: .bold))
                        .tracking(0.65)
                        .opacity(0.66)

                    Text(entry.artifact?.title ?? "Open Human Collective")
                        .font(.system(size: 12.5, weight: .bold, design: .serif))
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)
                        .allowsTightening(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let artifact = entry.artifact {
            return "Today's artifact: \(artifact.title)"
        }
        return entry.errorMessage ?? "Today's Human Collective artifact"
    }
}

struct DailyArtifactWidget: Widget {
    private let kind = "com.sam.HumanCollective.dailyArtifact"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyArtifactProvider()) { entry in
            DailyArtifactWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Artifact")
        .description("See today's Human Collective artifact at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular
        ])
        .contentMarginsDisabled()
    }
}

private extension DailyArtifactEntry {
    static let preview = DailyArtifactEntry(
        date: Date(),
        artifact: WidgetArtifact(
            title: "Rosetta Stone",
            imageURL: URL(string: "https://example.com/rosetta-stone.jpg")!,
            category: "Artifact",
            detail: "Ptolemaic Egypt"
        ),
        imageData: nil,
        errorMessage: nil
    )
}
