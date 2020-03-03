//
//  ImageUtils.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 03.03.20.
//

import Foundation
import LoggerAPI
import Kitura

internal class ImageUtils {

    private init() {}

    internal static func combineImages(staticPath: String, markerPath: String, destinationPath: String, marker: Marker, scale: UInt8, centerLat: Double, centerLon: Double, zoom: UInt8) throws {

        let realOffset = getRealOffset(
            at: Coordinate(latitude: marker.latitude, longitude: marker.longitude) ,
            relativeTo: Coordinate(latitude: centerLat, longitude: centerLon),
            zoom: zoom,
            scale: scale,
            extraX: marker.xOffset,
            extraY: marker.yOffset
        )

        let realOffsetXPrefix: String
        if realOffset.x >= 0 {
            realOffsetXPrefix = "+"
        } else {
            realOffsetXPrefix = ""
        }
        let realOffsetYPrefix: String
        if realOffset.y >= 0 {
            realOffsetYPrefix = "+"
        } else {
            realOffsetYPrefix = ""
        }

        let shell = Shell(
            "/usr/local/bin/convert",
            staticPath,
            "(", markerPath, "-resize", "\(marker.width * UInt16(scale))x\(marker.height * UInt16(scale))", ")",
            "-gravity", "Center",
            "-geometry", "\(realOffsetXPrefix)\(realOffset.x)\(realOffsetYPrefix)\(realOffset.y)",
            "-composite",
            destinationPath
        )
        let error = shell.runError() ?? ""
        guard error == "" else {
            Log.error("Failed to run magick: \(error)")
            throw RequestError.internalServerError
        }

    }

    internal static func drawPolygon(staticPath: String, destinationPath: String, polygon: Polygon, scale: UInt8, centerLat: Double, centerLon: Double, zoom: UInt8, width: UInt16, height: UInt16) throws {

        var points = [(x: Int, y: Int)]()

        for coord in polygon.path {
            guard coord.count == 2 else {
                throw RequestError.badGateway
            }
            let point = getRealOffset(
                at: Coordinate(latitude: coord[0], longitude: coord[1]) ,
                relativeTo: Coordinate(latitude: centerLat, longitude: centerLon),
                zoom: zoom,
                scale: scale,
                extraX: 0,
                extraY: 0
            )
            points.append((x: point.x + (Int(width/2*UInt16(scale))), y: point.y + Int(height/2*UInt16(scale))))
        }

        var polygonPath = ""
        for point in points {
            polygonPath += "\(point.x),\(point.y) "
        }
        polygonPath.removeLast()

        let shell = Shell(
            "/usr/local/bin/convert",
            staticPath,
            "-strokewidth", "\(polygon.strokeWidth)",
            "-fill", polygon.fillColor,
            "-stroke", polygon.strokeColor,
            "-gravity", "Center",
            "-draw", "polygon \(polygonPath)",
            destinationPath
        )
        let error = shell.runError() ?? ""
        guard error == "" else {
            Log.error("Failed to run magick: \(error)")
            throw RequestError.internalServerError
        }

    }

    private static func getRealOffset(at: Coordinate, relativeTo center: Coordinate, zoom: UInt8, scale: UInt8, extraX: Int16, extraY: Int16) -> (x: Int, y: Int) {
        let realOffsetX: Int
        let realOffsetY: Int
        if center.latitude == at.latitude && center.longitude == at.longitude {
            realOffsetX = 0
            realOffsetY = 0
        } else {
            if let px1 = SphericalMercator().px(coordinate: Coordinate(latitude: center.latitude, longitude: center.longitude), zoom: 20),
                let px2 = SphericalMercator().px(coordinate: Coordinate(latitude: at.latitude, longitude: at.longitude), zoom: 20) {
                let pxScale = pow(2, Double(zoom) - 20)
                realOffsetX = Int((px2.x - px1.x) * Double(pxScale) * Double(scale))
                realOffsetY = Int((px2.y - px1.y) * Double(pxScale) * Double(scale))
            } else {
                realOffsetX = 0
                realOffsetY = 0
            }
        }
        return (realOffsetX + (Int(extraX) * Int(scale)), realOffsetY + (Int(extraY) * Int(scale)))
    }

}
