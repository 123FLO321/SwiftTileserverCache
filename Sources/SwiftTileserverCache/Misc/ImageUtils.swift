//
//  ImageUtils.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 03.03.20.
//

import Foundation
import Vapor
import ShellOut

public class ImageUtils {
    
    private init() {}
    
    #if os(macOS)
    private static let imagemagickConvertCommand = "/usr/local/bin/convert"
    #else
    private static let imagemagickConvertCommand = "/usr/bin/convert"
    #endif
    
    // MARK: - Generation
    
    public static func generateStaticMap(request: Request, staticMap: StaticMap, basePath: String, path: String) -> EventLoopFuture<Void> {
        var polygonArguments = [String]()
        for polygon in staticMap.polygons ?? [] {
            var points = [(x: Int, y: Int)]()
            
            for coord in polygon.path {
                guard coord.count == 2 else {
                    return request.eventLoop.future(error: Abort(.badRequest, reason: "Expecting two values to form a coordinate but got \(coord.count)"))
                }
                let point = getRealOffset(
                    at: Coordinate(latitude: coord[0], longitude: coord[1]) ,
                    relativeTo: Coordinate(latitude: staticMap.latitude, longitude: staticMap.longitude),
                    zoom: staticMap.zoom,
                    scale: staticMap.scale,
                    extraX: 0,
                    extraY: 0
                )
                points.append((x: point.x + (Int(staticMap.width/2*UInt16(staticMap.scale))), y: point.y + Int(staticMap.height/2*UInt16(staticMap.scale))))
            }
            
            var polygonPath = ""
            for point in points {
                polygonPath += "\(point.x),\(point.y) "
            }
            polygonPath.removeLast()
            
            polygonArguments += [
                "-strokewidth", "\(polygon.strokeWidth)",
                "-fill", polygon.fillColor.bashEncoded,
                "-stroke", polygon.strokeColor.bashEncoded,
                "-gravity", "Center",
                "-draw", "\"polygon \(polygonPath)\""
            ]
        }
        
        var markerArguments = [String]()
        for marker in staticMap.markers ?? [] {
            let realOffset = getRealOffset(
                at: Coordinate(latitude: marker.latitude, longitude: marker.longitude),
                relativeTo: Coordinate(latitude: staticMap.latitude, longitude: staticMap.longitude),
                zoom: staticMap.zoom,
                scale: staticMap.scale,
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

            let markerPath: String
            if marker.url.starts(with: "http://") || marker.url.starts(with: "https://") {
                let markerHashed = marker.url.persistentHash
                let markerFormat = marker.url.components(separatedBy: ".").last ?? "png"
                markerPath = "Cache/Marker/\(markerHashed).\(markerFormat)"
            } else {
                markerPath = "Markers/\(marker.url)"
            }
            markerArguments += [
                "\\(", markerPath, "-resize", "\(marker.width * UInt16(staticMap.scale))x\(marker.height * UInt16(staticMap.scale))", "\\)",
                "-gravity", "Center",
                "-geometry", "\(realOffsetXPrefix)\(realOffset.x)\(realOffsetYPrefix)\(realOffset.y)",
                "-composite"
            ]
            
        }
        
        return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
            do {
                try shellOut(to: imagemagickConvertCommand, arguments: [
                    basePath] +
                    polygonArguments +
                    markerArguments +
                    [path
                ])
            } catch let error as ShellOutError {
                request.application.logger.error("Failed to run magick: \(error.message)")
                throw Abort(.internalServerError, reason: "ImageMagick Error: \(error.message)")
            } catch {
                request.application.logger.error("Failed to run magick: \(error)")
                throw Abort(.internalServerError, reason: "ImageMagick Error")
            }
        }
        
    }
    
    public static func generateMultiStaticMap(request: Request, multiStaticMap: MultiStaticMap, path: String) -> EventLoopFuture<Void> {
        var grids = [(firstPath: String, direction: CombineDirection, images: [(direction: CombineDirection, path: String)])]()
        for grid in multiStaticMap.grid {
            var firstMapUrl = ""
            var images = [(CombineDirection, String)]()
            for map in grid.maps {
                let url = map.map.path
                if map.direction == .first {
                    firstMapUrl = url
                } else {
                    images.append((map.direction, url))
                }
            }
            grids.append((firstMapUrl, grid.direction, images))
        }
        
        var args = [String]()
        for grid in grids {
            args.append("\\(")
            args.append(grid.firstPath)
            for image in grid.images {
                args.append(image.path)
                if image.direction == .bottom {
                    args.append("-append")
                } else {
                    args.append("+append")
                }
            }
            args.append("\\)")
            if grid.direction == .bottom {
                args.append("-append")
            } else {
                args.append("+append")
            }
        }
        args.append(path)
        
        return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
            do {
                try shellOut(to: imagemagickConvertCommand, arguments: args)
            } catch let error as ShellOutError {
                request.application.logger.error("Failed to run magick: \(error.message)")
                throw Abort(.internalServerError, reason: "ImageMagick Error: \(error.message)")
            } catch {
                request.application.logger.error("Failed to run magick: \(error)")
                throw Abort(.internalServerError, reason: "ImageMagick Error")
            }
        }
    }
    
    // MARK: - Utils
    
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
