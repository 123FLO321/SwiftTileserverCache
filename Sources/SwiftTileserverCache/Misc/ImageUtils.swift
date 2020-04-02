//
//  ImageUtils.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 03.03.20.
//

import Foundation
import FileKit
import LoggerAPI
import Kitura

internal class ImageUtils {

    private init() {}

    internal static func combineImages(staticPath: String, markerPath: String, destinationPath: String, marker: Marker, scale: UInt8, centerLat: Double, centerLon: Double, zoom: Double) throws {

        let realOffset = getRealOffset(
            at: Coordinate(latitude: marker.latitude, longitude: marker.longitude) ,
            relativeTo: Coordinate(latitude: centerLat, longitude: centerLon),
            zoom: zoom,
            scale: scale,
            extraX: marker.xOffset ?? 0,
            extraY: marker.yOffset ?? 0
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
        let errorString: String
        do {
            errorString = try shell.runError() ?? ""
        } catch {
            Log.error("Failed to run magick command: \(error)")
            throw RequestError(rawValue: 500, reason: "ImageMagick Error")
        }
        guard errorString == "" else {
            Log.error("Failed to run magick: \(errorString)")
            throw RequestError(rawValue: 500, reason: "ImageMagick Error")
        }

    }

    internal static func combineImages(grids: [(firstPath: String, direction: CombineDirection, images: [(direction: CombineDirection, path: String)])], destinationPath: String) throws {
        var args = [
            "/usr/local/bin/convert"
        ]
        for grid in grids {
            args.append("(")
            args.append(grid.firstPath)
            for image in grid.images {
                args.append(image.path)
                if image.direction == .bottom {
                    args.append("-append")
                } else {
                    args.append("+append")
                }
            }
            args.append(")")
            if grid.direction == .bottom {
                args.append("-append")
            } else {
                args.append("+append")
            }
        }
        args.append(destinationPath)
        let shell = Shell(args)
        let errorString: String
        do {
            errorString = try shell.runError() ?? ""
        } catch {
            Log.error("Failed to run magick command: \(error)")
            throw RequestError(rawValue: 500, reason: "ImageMagick Error")
        }
        guard errorString == "" else {
            Log.error("Failed to run magick: \(errorString)")
            throw RequestError(rawValue: 500, reason: "ImageMagick Error")
        }
    }

    internal static func drawPolygon(staticPath: String, destinationPath: String, polygon: Polygon, scale: UInt8, centerLat: Double, centerLon: Double, zoom: Double, width: UInt16, height: UInt16) throws {

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
        let errorString: String
        do {
            errorString = try shell.runError() ?? ""
        } catch {
            Log.error("Failed to run magick command: \(error)")
            throw RequestError(rawValue: 500, reason: "ImageMagick Error")
        }
        guard errorString == "" else {
            Log.error("Failed to run magick: \(errorString)")
            throw RequestError(rawValue: 500, reason: "ImageMagick Error")
        }

    }

    private static func getRealOffset(at: Coordinate, relativeTo center: Coordinate, zoom: Double, scale: UInt8, extraX: Int16, extraY: Int16) -> (x: Int, y: Int) {
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
