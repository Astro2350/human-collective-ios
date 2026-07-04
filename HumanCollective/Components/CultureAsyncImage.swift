import SwiftUI

struct CultureAsyncImage: View {
    let imageURL: String
    var aspectRatio: CGFloat = HCTheme.feedImageAspectRatio
    var cornerRadius: CGFloat = HCTheme.cardRadius

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HCTheme.surfaceDeep

                AsyncImage(url: resolvedURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(HCTheme.secondaryInk)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .transition(.opacity)
                    case .failure:
                        placeholder
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    @unknown default:
                        placeholder
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(HCTheme.line.opacity(0.48), lineWidth: HCTheme.hairline)
            }
            .clipped()
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 30, weight: .light))
            .foregroundStyle(HCTheme.secondaryInk.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedURL: URL? {
        Self.normalizedImageURL(from: imageURL)
    }

    static func normalizedImageURL(from imageURL: String) -> URL? {
        guard let url = URL(string: imageURL) else { return nil }

        let marker = "/wikipedia/commons/thumb/"
        guard imageURL.contains("upload.wikimedia.org"),
              let range = imageURL.range(of: marker) else {
            return url
        }

        let remainder = imageURL[range.upperBound...]
        let pathParts = remainder.split(separator: "/")
        guard pathParts.count >= 3 else { return url }

        let fileName = pathParts[2]
        let redirectURL = "https://commons.wikimedia.org/wiki/Special:Redirect/file/\(fileName)?width=900"
        return URL(string: redirectURL) ?? url
    }
}
