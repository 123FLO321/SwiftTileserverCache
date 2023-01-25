import Foundation

public struct Polygon: Codable, Hashable, Drawable {
    public var fillColor: String
    public var strokeColor: String
    public var strokeWidth: UInt8
    public var path: [[Double]]
    
    enum CodingKeys: String, CodingKey {
        case fillColor = "fill_color", strokeColor = "stroke_color", path, strokeWidth = "stroke_width"
    }
}
