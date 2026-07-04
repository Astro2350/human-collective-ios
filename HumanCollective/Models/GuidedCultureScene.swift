import Foundation

struct GuidedCultureScene: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let focusX: Double
    let focusY: Double
    let zoom: Double
    let highlightX: Double?
    let highlightY: Double?
    let highlightRadius: Double?
    let callout: String?
    let imageURLOverride: String?
    let sceneIndex: Int

    init(
        id: String,
        title: String,
        body: String,
        focusX: Double,
        focusY: Double,
        zoom: Double,
        highlightX: Double? = nil,
        highlightY: Double? = nil,
        highlightRadius: Double? = nil,
        callout: String? = nil,
        imageURLOverride: String? = nil,
        sceneIndex: Int
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.focusX = focusX
        self.focusY = focusY
        self.zoom = zoom
        self.highlightX = highlightX
        self.highlightY = highlightY
        self.highlightRadius = highlightRadius
        self.callout = callout
        self.imageURLOverride = imageURLOverride
        self.sceneIndex = sceneIndex
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case focusX = "focus_x"
        case focusY = "focus_y"
        case zoom
        case highlightX = "highlight_x"
        case highlightY = "highlight_y"
        case highlightRadius = "highlight_radius"
        case callout
        case imageURLOverride = "image_url_override"
        case sceneIndex = "scene_index"
    }
}
