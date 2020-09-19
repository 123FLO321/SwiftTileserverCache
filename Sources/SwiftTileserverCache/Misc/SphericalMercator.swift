//
//  SphericalMercator.swift
//  SwiftTileserverCache
//
//  From: https://github.com/qin9smile/sphericalmercator.swift/blob/master/sphericalmercator.swift
//

import Foundation

public struct Coordinate {
    public var latitude: Double
    public var longitude: Double


    // Source: https://github.com/mapbox/turf-swift
    public func coordinate(at distance: Double, facing direction: Double) -> Coordinate {
        let distance = distance / 6_373_000.0
        let direction = direction
        let latitude = self.latitude * .pi / 180.0
        let longitude = self.longitude * .pi / 180.0
        let otherLatitude = asin(
            sin(latitude) * cos(distance) + cos(latitude) * sin(distance) * cos(direction)
        )
        let otherLongitude = longitude + atan2(
            sin(direction) * sin(distance) * cos(latitude),
            cos(distance) - sin(latitude) * sin(otherLatitude)
        )
        return Coordinate(latitude: otherLatitude * 180.0 / .pi, longitude: otherLongitude * 180.0 / .pi)
    }

}

public class SphericalMercator {
    let EPSLN = 1.0e-10
    let D2R = Double.pi / 180
    let R2D = 180 / Double.pi
    let A = 6378137.0
    let MAXEXTENT = 20037508.342789244

    let size: Double


    var cache: [Double: CacheSize] = [:]

    class CacheSize {
        var Bc: [Double] = []
        var Cc: [Double] = []
        var zc: [Double] = []
        var Ac: [Double] = []
    }

    class Bounds {
        var ws: Coordinate
        var en: Coordinate

        public init(ws: Coordinate, en: Coordinate) {
            self.ws = ws
            self.en = en
        }
    }

    class XYZBounds {
        var minPoint: Point
        var maxPoint: Point

        public init(minPoint: Point, maxPoint: Point) {
            self.minPoint = minPoint
            self.maxPoint = maxPoint
        }
    }

    class Point {
        var x: Double
        var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public init() {
        self.size = 256;
        if cache[self.size] == nil {
            var size = self.size
            cache[size] = CacheSize()
            let c = cache[size]
            for _ in 0..<30 {
                c?.Bc.append(size / 360)
                c?.Cc.append(size / (2 * Double.pi))
                c?.zc.append(size / 2)
                c?.Ac.append(size)
                size *= 2
            }
        }
    }

    /// Convert lon lat to screen pixel value
    func px(coordinate: Coordinate, zoom: Int) -> Point? {
        guard let cacheSize = cache[size] else {
            return nil
        }

        let d = cacheSize.zc[zoom]
        let f = min(max(sin(D2R * coordinate.latitude), -0.9999), 0.9999)
        var x = round(d + coordinate.longitude * cacheSize.Bc[zoom])
        var y = round(d + 0.5 * log((1 + f) / (1 - f)) * (-cacheSize.Cc[zoom]))
        if x > cacheSize.Ac[zoom] {
            x = cacheSize.Ac[zoom]
        }

        if y > cacheSize.Ac[zoom] {
            y = cacheSize.Ac[zoom]
        }
        return Point(x: x, y: y)
    }

    /// Convert screen pixel value to Coordinate
    func ll(px: Point, zoom: Int) -> Coordinate? {
        guard let cacheSize = cache[size] else {
            return nil
        }
        let g = (Double(px.y) - cacheSize.zc[zoom]) / (-cacheSize.Cc[zoom])
        let longitude = (Double(px.x) - cacheSize.zc[zoom]) / cacheSize.Bc[zoom]
        let latitude = R2D * (2 * atan(exp(g)) - 0.5 * Double.pi)
        return Coordinate.init(latitude: latitude, longitude: longitude)
    }

    /// Convert tile xyz value to Bounds of the form
    func bbox(x: Double, y: Double, zoom: Int, tmsStyle: Bool, srs: String) -> Bounds {
        var _y = y
        if tmsStyle {
            _y = (Double(truncating: NSDecimalNumber(decimal: pow(2, zoom))) - 1) - y
        }

        let ws = ll(px: Point(x: x * size, y: (+_y + 1) * size), zoom: zoom)!
        let en = ll(px: Point(x: (+x + 1) * size, y: _y * size), zoom: zoom)!
        let bounds = Bounds(ws: ws, en: en)
        if srs == "900913" {
            return convert(bounds, to: "900913")
        }
        return bounds
    }

    /// Convert bbounds to xyz bounds
    func xyz(bbox: Bounds, zoom: Int, tmsStyle: Bool, srs: String) -> XYZBounds {
        var _bbox = bbox
        if srs == "900913" {
            _bbox = convert(bbox, to: "WGS84")
        }

        let px_ll = px(coordinate: _bbox.ws, zoom: zoom)!
        let px_ur = px(coordinate: _bbox.en, zoom: zoom)!

        // Y = 0 for XYZ is the top hency minY use px_ur.y
        let x = [floor(px_ll.x / size), floor((px_ur.x - 1) / size)]
        let y = [floor(px_ur.y / size), floor((px_ll.y - 1) / size)]

        let xyzBounds = XYZBounds(minPoint: Point(x: x.min()! < 0 ? 0 : x.min()!, y: y.min()! < 0 ? 0 : y.min()!), maxPoint: Point(x: x.max()!, y: y.max()!))

        if tmsStyle {
            let minY = Double(truncating: NSDecimalNumber(decimal: pow(2, zoom))) - 1 - xyzBounds.maxPoint.y
            let maxY = Double(truncating: NSDecimalNumber(decimal: pow(2, zoom))) - 1 - xyzBounds.minPoint.y
            xyzBounds.minPoint.y = minY
            xyzBounds.maxPoint.y = maxY
        }

        return xyzBounds
    }

    /// Convert bbounds to xyz bounds
    func xy(coord: Coordinate, zoom: Int) -> (x: Int, y: Int, xDelta: Int16, yDelta: Int16) {
        let pxC = px(coordinate: coord, zoom: zoom)!
        let x = Int(pxC.x / size)
        let xDelta = Int16(pxC.x.truncatingRemainder(dividingBy: size))
        let y = Int(pxC.y / size)
        let yDelta = Int16(pxC.y.truncatingRemainder(dividingBy: size))
        return (x, y, xDelta, yDelta)
    }

    /// Convert projection of given bbox
    func convert(_ bounds: Bounds, to srs: String) -> Bounds {
        if srs == "900913" {
            let point1 = forward(bounds.ws)
            let point2 = forward(bounds.en)
            return Bounds(ws: Coordinate(latitude: point1.x, longitude: point1.y), en: Coordinate(latitude: point2.x, longitude: point2.y))
        } else {
            let point1 = inverse(Point(x: bounds.ws.latitude, y: bounds.ws.longitude))
            let point2 = inverse(Point(x: bounds.en.latitude, y: bounds.en.longitude))
            return Bounds(ws: point1, en: point2)
        }
    }

    // Convert Coordinate to 900913 Point
    func forward(_ coordinate: Coordinate) -> Point {
        let point = Point(x: A * coordinate.longitude * D2R,
                          y: A * log(tan(Double.pi * 0.25 + 0.5 * coordinate.latitude * D2R)))

        // if xy value is beyond maxextent (e.g. poles), return maxextent.
        if point.x > MAXEXTENT {
            point.x = MAXEXTENT
        } else if point.x < -MAXEXTENT {
            point.x = -MAXEXTENT
        }

        if point.y > MAXEXTENT {
            point.y = MAXEXTENT
        } else if point.y < -MAXEXTENT {
            point.y = -MAXEXTENT
        }

        return point
    }

    // Convert 900913 Point to Coordinate
    func inverse(_ point: Point) -> Coordinate {
        return Coordinate.init(latitude: (Double.pi * 0.5) - 2.0 * atan(exp(-point.y / A)) * R2D, longitude: point.x * R2D / A)
    }
}
