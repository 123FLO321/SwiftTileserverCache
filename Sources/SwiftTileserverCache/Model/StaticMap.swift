//
//  StaticMap.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 04.03.20.
//

import Foundation
import Cryptor

public struct StaticMap: Codable, Hashable, PersistentHashable {
    public var style: String
    public var latitude: Double
    public var longitude: Double
    public var zoom: UInt8
    public var width: UInt16
    public var height: UInt16
    public var scale: UInt8
    public var format: String?
    public var bearing: Double?
    public var pitch: Double?
    public var markers: [Marker]?
    public var polygons: [Polygon]?
}
