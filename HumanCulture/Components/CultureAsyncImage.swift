import SwiftUI

struct CultureAsyncImage: View {
    let imageURL: String
    var aspectRatio: CGFloat = 1.18
    var cornerRadius: CGFloat = HCTheme.cardRadius

    var body: some View {
        ZStack {
            HCTheme.surfaceDeep

            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(HCTheme.secondaryInk)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.45), lineWidth: 1)
        }
        .clipped()
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 30, weight: .light))
            .foregroundStyle(HCTheme.secondaryInk.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

