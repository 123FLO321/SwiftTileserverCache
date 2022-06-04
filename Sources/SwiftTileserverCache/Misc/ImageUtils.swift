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

    public static func generateBaseStaticMap(request: Request, staticMap: StaticMap, tilePaths: [String], path: String, offsetX: Int, offsetY: Int, hasScale: Bool) -> EventLoopFuture<Void> {

        var args: [String]
        if tilePaths.count == 1 {
            args = tilePaths
        } else {
            var lastY: Int?
            var currentSemgent = 0
            var segments = [[String]]()
            for tilePath in tilePaths.sorted() {
                if segments.count == 0 {
                    segments.append(["("])
                }
                let split = tilePath.components(separatedBy: "-")
                let y = Int(split[split.count-3]) ?? 0
                if (lastY != nil) {
                    if y == lastY {
                        segments[currentSemgent].append(tilePath)
                        segments[currentSemgent].append("-append")
                    } else {
                        segments[currentSemgent].append(")")
                        if segments.count != 1 {
                            segments[currentSemgent].append("+append")
                        }
                        currentSemgent += 1
                        segments.append(["("])
                        segments[currentSemgent].append(tilePath)
                    }
                } else {
                    segments[currentSemgent].append(tilePath)
                }
                lastY = y
            }
            segments[currentSemgent].append(")")
            segments[currentSemgent].append("+append")
            args = segments.flatMap({$0})
        }

        let imgWidth: Int
        let imgHeight: Int
        let imgWidthOffset: Int
        let imgHeightOffset: Int
        if hasScale && staticMap.scale > 1 {
            imgWidth = Int(staticMap.width) * Int(staticMap.scale)
            imgHeight = Int(staticMap.height) * Int(staticMap.scale)
            imgWidthOffset = (offsetX - Int(staticMap.width) / 2) * Int(staticMap.scale)
            imgHeightOffset = (offsetY - Int(staticMap.height) / 2) * Int(staticMap.scale)
        } else {
            imgWidth = Int(staticMap.width)
            imgHeight = Int(staticMap.height)
            imgWidthOffset = offsetX - Int(staticMap.width) / 2
            imgHeightOffset = offsetY - Int(staticMap.height) / 2
        }
        args += ["-crop", "\(imgWidth)x\(imgHeight)+\(imgWidthOffset)+\(imgHeightOffset)", "+repage", path]
        return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
            do {
                try escapedShellOut(to: ImageUtils.imagemagickConvertCommand, arguments: args)
            } catch let error as ShellOutError {
                request.application.logger.error("Failed to run magick: \(error.message)")
                throw Abort(.internalServerError, reason: "ImageMagick Error: \(error.message)")
            } catch {
                request.application.logger.error("Failed to run magick: \(error)")
                throw Abort(.internalServerError, reason: "ImageMagick Error")
            }
        }
    }

    public static func generateStaticMap(request: Request, staticMap: StaticMap, basePath: String, path: String, sphericalMercator: SphericalMercator) -> EventLoopFuture<Void> {
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
                    extraY: 0,
                    sphericalMercator: sphericalMercator
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
                "-fill", polygon.fillColor,
                "-stroke", polygon.strokeColor,
                "-gravity", "Center",
                "-draw", "polygon \(polygonPath)"
            ]
        }

        var circleArguments = [String]()
        for circle in staticMap.circles ?? [] {
            let coord = Coordinate(latitude: circle.latitude, longitude: circle.longitude)
            let point = getRealOffset(
                at: coord,
                relativeTo: Coordinate(latitude: staticMap.latitude, longitude: staticMap.longitude),
                zoom: staticMap.zoom,
                scale: staticMap.scale,
                extraX: 0,
                extraY: 0,
                sphericalMercator: sphericalMercator
            )
            let radius = getRealOffset(
                at: coord,
                relativeTo: coord.coordinate(at: circle.radius, facing: 0),
                zoom: staticMap.zoom,
                scale: staticMap.scale,
                extraX: 0,
                extraY: 0,
                sphericalMercator: sphericalMercator
            ).y
            let x = point.x + Int(staticMap.width * UInt16(staticMap.scale) / 2)
            let y = point.y + Int(staticMap.height * UInt16(staticMap.scale) / 2)

            circleArguments += [
                "-strokewidth", "\(circle.strokeWidth)",
                "-fill", circle.fillColor,
                "-stroke", circle.strokeColor,
                "-gravity", "Center",
                "-draw", "circle \(x),\(y) \(x),\(y+radius)"
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
                extraY: marker.yOffset ?? 0,
                sphericalMercator: sphericalMercator
            )

            if (abs(realOffset.x) > (staticMap.width + marker.width) * UInt16(staticMap.scale) / 2) ||
               (abs(realOffset.y) > (staticMap.height + marker.height) * UInt16(staticMap.scale) / 2) {
                continue
            }

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

            var markerPath: String
            if marker.url.starts(with: "http://") || marker.url.starts(with: "https://") {
                let markerHashed = marker.url.persistentHash
                let markerFormat = marker.url.components(separatedBy: ".").last ?? "png"
                markerPath = "Cache/Marker/\(markerHashed).\(markerFormat)"
            } else {
                markerPath = "Markers/\(marker.url)"
            }
            if let fallbackUrl = marker.fallbackUrl, !FileManager.default.fileExists(atPath: markerPath) {
                if fallbackUrl.starts(with: "http://") || fallbackUrl.starts(with: "https://") {
                    let markerHashed = fallbackUrl.persistentHash
                    let markerFormat = fallbackUrl.components(separatedBy: ".").last ?? "png"
                    markerPath = "Cache/Marker/\(markerHashed).\(markerFormat)"
                } else {
                    markerPath = "Markers/\(fallbackUrl)"
                }
            }

            markerArguments += [
                "(", markerPath, "-resize", "\(marker.width * UInt16(staticMap.scale))x\(marker.height * UInt16(staticMap.scale))", ")",
                "-gravity", "Center",
                "-geometry", "\(realOffsetXPrefix)\(realOffset.x)\(realOffsetYPrefix)\(realOffset.y)",
                "-composite"
            ]
            
        }
        
        return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
            do {
                let args = [basePath] +
                    polygonArguments +
                    circleArguments +
                    markerArguments +
                    [path]

                try escapedShellOut(to: ImageUtils.imagemagickConvertCommand, arguments: args)
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
        args.append(path)
        
        return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
            do {
                try escapedShellOut(to: imagemagickConvertCommand, arguments: args)
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
    
    private static func getRealOffset(at: Coordinate, relativeTo center: Coordinate, zoom: Double, scale: UInt8, extraX: Int16, extraY: Int16, sphericalMercator: SphericalMercator) -> (x: Int, y: Int) {
        let realOffsetX: Int
        let realOffsetY: Int
        if center.latitude == at.latitude && center.longitude == at.longitude {
            realOffsetX = 0
            realOffsetY = 0
        } else {
            if let px1 = sphericalMercator.px(coordinate: Coordinate(latitude: center.latitude, longitude: center.longitude), zoom: 20),
                let px2 = sphericalMercator.px(coordinate: Coordinate(latitude: at.latitude, longitude: at.longitude), zoom: 20) {
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
