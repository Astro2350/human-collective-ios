import Foundation

enum CultureCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case painting
    case sculpture
    case artifact
    case textile
    case architecture
    case manuscript
    case poster
    case object
    case map
    case jewelry
    case pottery
    case mask
    case tool
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .painting: "Painting"
        case .sculpture: "Sculpture"
        case .artifact: "Artifact"
        case .textile: "Textile"
        case .architecture: "Architecture"
        case .manuscript: "Manuscript"
        case .poster: "Print"
        case .object: "Object"
        case .map: "Map"
        case .jewelry: "Jewelry"
        case .pottery: "Pottery"
        case .mask: "Mask"
        case .tool: "Tool"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .painting: "paintpalette"
        case .sculpture: "person.crop.square"
        case .artifact: "shippingbox"
        case .textile: "square.grid.3x3"
        case .architecture: "building.columns"
        case .manuscript: "book.closed"
        case .poster: "doc.richtext"
        case .object: "cube"
        case .map: "map"
        case .jewelry: "sparkle"
        case .pottery: "cup.and.saucer"
        case .mask: "theatermasks"
        case .tool: "hammer"
        case .other: "circle.grid.cross"
        }
    }
}
