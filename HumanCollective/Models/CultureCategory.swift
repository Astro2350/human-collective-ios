import Foundation

enum CultureCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case meme
    case painting
    case sculpture
    case architecture
    case car
    case watch
    case furniture
    case fashion
    case food
    case drink
    case instrument
    case invention
    case machine
    case tool
    case film
    case music
    case game
    case book
    case monument
    case publicSpace = "public_space"
    case engineeringFeat = "engineering_feat"
    case artifact
    case textile
    case manuscript
    case poster
    case object
    case map
    case jewelry
    case pottery
    case mask
    case photography
    case craft
    case art
    case design
    case writing
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meme: "Meme"
        case .painting: "Painting"
        case .sculpture: "Sculpture"
        case .architecture: "Architecture"
        case .car: "Car"
        case .watch: "Watch"
        case .furniture: "Furniture"
        case .fashion: "Fashion"
        case .food: "Food"
        case .drink: "Drink"
        case .instrument: "Instrument"
        case .invention: "Invention"
        case .machine: "Machine"
        case .tool: "Tool"
        case .film: "Film"
        case .music: "Music"
        case .game: "Game"
        case .book: "Book"
        case .monument: "Monument"
        case .publicSpace: "Public Space"
        case .engineeringFeat: "Engineering Feat"
        case .artifact: "Artifact"
        case .textile: "Textile"
        case .manuscript: "Manuscript"
        case .poster: "Print"
        case .object: "Object"
        case .map: "Map"
        case .jewelry: "Jewelry"
        case .pottery: "Pottery"
        case .mask: "Mask"
        case .photography: "Photography"
        case .craft: "Craft"
        case .art: "Art"
        case .design: "Design"
        case .writing: "Writing"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .meme: "face.smiling"
        case .painting: "paintpalette"
        case .sculpture: "person.crop.square"
        case .architecture: "building.columns"
        case .car: "car.side"
        case .watch: "watch.analog"
        case .furniture: "chair.lounge"
        case .fashion: "tshirt"
        case .food: "fork.knife"
        case .drink: "wineglass"
        case .instrument: "guitars"
        case .invention: "lightbulb"
        case .machine: "gearshape.2"
        case .tool: "hammer"
        case .film: "film"
        case .music: "music.note"
        case .game: "gamecontroller"
        case .book: "books.vertical"
        case .monument: "building.columns.fill"
        case .publicSpace: "tree"
        case .engineeringFeat: "ruler"
        case .artifact: "shippingbox"
        case .textile: "square.grid.3x3"
        case .manuscript: "book.closed"
        case .poster: "doc.richtext"
        case .object: "cube"
        case .map: "map"
        case .jewelry: "sparkle"
        case .pottery: "cup.and.saucer"
        case .mask: "theatermasks"
        case .photography: "camera"
        case .craft: "scissors"
        case .art: "paintbrush"
        case .design: "pencil.and.ruler"
        case .writing: "text.book.closed"
        case .other: "circle.grid.cross"
        }
    }

    var title: String {
        switch self {
        case .meme: "Memes"
        case .painting: "Paintings"
        case .sculpture: "Sculptures"
        case .car: "Cars"
        case .watch: "Watches"
        case .drink: "Drinks"
        case .instrument: "Instruments"
        case .invention: "Inventions"
        case .machine: "Machines"
        case .tool: "Tools"
        case .film: "Films"
        case .game: "Games"
        case .book: "Books"
        case .monument: "Monuments"
        case .publicSpace: "Public Spaces"
        case .engineeringFeat: "Engineering Feats"
        default: displayName
        }
    }

    static let collectiveCases: [CultureCategory] = [
        .meme,
        .painting, .sculpture, .architecture,
        .car, .watch, .furniture, .fashion,
        .food, .drink, .instrument,
        .invention, .machine, .tool,
        .film, .music, .game, .book,
        .monument, .publicSpace, .engineeringFeat,
        .other
    ]
}
