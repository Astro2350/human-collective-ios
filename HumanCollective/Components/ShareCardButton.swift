import SwiftUI
import UIKit

struct ArtifactShareButton: View {
    let item: CultureItem

    @State private var isPreparing = false
    @State private var isSharing = false
    @State private var activityItems: [Any] = []

    var body: some View {
        Button {
            Task { await prepareShare() }
        } label: {
            HStack {
                if isPreparing { ProgressView() }
                Label(isPreparing ? "Preparing…" : "Share", systemImage: "square.and.arrow.up")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(HCTheme.blueStone)
        .disabled(isPreparing)
        .sheet(isPresented: $isSharing) {
            ActivityShareView(activityItems: activityItems)
                .presentationDetents([.medium, .large])
        }
    }

    @MainActor
    private func prepareShare() async {
        guard !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        guard let url = URL(string: item.imageURL),
              let sourceImage = try? await CultureImageCache.shared.image(for: url) else {
            activityItems = [shareText]
            isSharing = true
            return
        }

        let card = ArtifactShareCardRenderer.render(item: item, image: sourceImage)
        activityItems = [card, shareText]
        isSharing = true
    }

    private var shareText: String {
        var parts = [item.displayTitle, item.creatorDisplay]
        if !item.dateDisplay.isEmpty { parts.append(item.dateDisplay) }
        if !item.sourceURL.isEmpty { parts.append(item.sourceURL) }
        return parts.joined(separator: " — ")
    }
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
enum ArtifactShareCardRenderer {
    static let size = CGSize(width: 1200, height: 1500)

    static func render(item: CultureItem, image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            warmBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let imageRect = CGRect(x: 72, y: 72, width: size.width - 144, height: 890)
            drawAspectFill(image, in: imageRect, context: context.cgContext)

            draw(
                "HUMAN COLLECTIVE",
                in: CGRect(x: 72, y: 1010, width: size.width - 144, height: 44),
                font: .systemFont(ofSize: 28, weight: .bold),
                color: clay,
                tracking: 4
            )
            draw(
                item.displayTitle,
                in: CGRect(x: 72, y: 1072, width: size.width - 144, height: 210),
                font: fittingFont(for: item.displayTitle, maximum: 72, minimum: 42, width: size.width - 144, height: 210),
                color: ink
            )
            draw(
                "\(item.creatorDisplay)  ·  \(item.dateDisplay)",
                in: CGRect(x: 72, y: 1322, width: size.width - 144, height: 80),
                font: .systemFont(ofSize: 30, weight: .semibold),
                color: secondaryInk
            )
        }
    }
}

private let warmBackground = UIColor(red: 0.963, green: 0.948, blue: 0.918, alpha: 1)
private let ink = UIColor(red: 0.105, green: 0.095, blue: 0.082, alpha: 1)
private let secondaryInk = UIColor(red: 0.29, green: 0.27, blue: 0.24, alpha: 1)
private let clay = UIColor(red: 0.56, green: 0.31, blue: 0.20, alpha: 1)

@MainActor
private func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
    guard image.size.width > 0, image.size.height > 0 else { return }
    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
    let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let drawRect = CGRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    context.saveGState()
    context.clip(to: rect)
    image.draw(in: drawRect)
    context.restoreGState()
}

@MainActor
private func fittingFont(for text: String, maximum: CGFloat, minimum: CGFloat, width: CGFloat, height: CGFloat) -> UIFont {
    for size in stride(from: maximum, through: minimum, by: -2) {
        let font = UIFont.systemFont(ofSize: size, weight: .bold)
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        if bounds.height <= height { return font }
    }
    return .systemFont(ofSize: minimum, weight: .bold)
}

@MainActor
private func draw(
    _ text: String,
    in rect: CGRect,
    font: UIFont,
    color: UIColor,
    tracking: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 5

    (text as NSString).draw(
        with: rect,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: tracking,
            .paragraphStyle: paragraph,
        ],
        context: nil
    )
}
