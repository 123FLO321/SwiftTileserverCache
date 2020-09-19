//
//  Circle.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 14.09.20.
//

import Foundation

public struct Circle: Codable, Hashable, Drawable {
    public var fillColor: String
    public var strokeColor: String
    public var strokeWidth: UInt8
    public var latitude: Double
    public var longitude: Double
    public var radius: Double

    enum CodingKeys: String, CodingKey {
        case fillColor = "fill_color", strokeColor = "stroke_color", radius, strokeWidth = "stroke_width", latitude, longitude
    }
}
