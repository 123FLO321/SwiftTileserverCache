//
//  StaticMap.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 04.03.20.
//

import Foundation

public struct StaticMap: Codable, Hashable, PersistentHashable {
    public var style: String
    public var latitude: Double
    public var longitude: Double
    public var zoom: Double
    public var width: UInt16
    public var height: UInt16
    public var scale: UInt8
    public var format: ImageFormat?
    public var bearing: Double?
    public var pitch: Double?
    public var markers: [Marker]?
    public var polygons: [Polygon]?
    public var circles: [Circle]?

    internal var path: String {
        return "Cache/Static/\(persistentHash).\(format ?? ImageFormat.png)"
    }
}
