//
//  WebServer.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 01.11.19.
//

import Foundation
import Kitura
import FileKit
import LoggerAPI

#if os(Linux)
import FoundationNetworking
#endif

public class WebServer {
    
    private let tileHitRatioLock = NSLock()
    private var tileHitRatio = [String: (hit: UInt64, miss: UInt64)]()
    
    private let staticHitRatioLock = NSLock()
    private var staticHitRatio = [String: (hit: UInt64, miss: UInt64)]()
    
    private let staticMarkerHitRatioLock = NSLock()
    private var staticMarkerHitRatio = [String: (hit: UInt64, miss: UInt64)]()
    
    private let markerHitRatioLock = NSLock()
    private var markerHitRatio: (hit: UInt64, miss: UInt64) = (hit: 0, miss: 0)
    
    private let router: Router
    private let tileServerURL: String
    
    public init(tileServerURL: String, port: Int=9000) {
        router = Router()
        self.tileServerURL = tileServerURL
        
        router.get("/", handler: getRoot)
        router.get("/tile/:style/:z/:x/:y/:scale/:format", handler: getTile)
        router.get("/static/:style/:lat/:lon/:zoom/:orientation:/:tilt:/:width:/:height/:scale:/:format", handler: getStatic)
        
        Kitura.addHTTPServer(onPort: port, with: router)
        Kitura.start()
    }
    
    private func getTile(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        guard
            let style = request.parameters["style"],
            let z = Int(request.parameters["z"] ?? ""),
            let x = Int(request.parameters["x"] ?? ""),
            let y = Int(request.parameters["y"] ?? ""),
            let scale = UInt8(request.parameters["scale"] ?? ""),
            scale >= 1,
            let format = request.parameters["format"],
            format == "png" || format == "jpg" else {
                throw RequestError.badRequest
        }
        
        let fileManager = FileManager()
        let fileName = "\(FileKit.projectFolder)/Cache/Tile/\(style)-\(z)-\(x)-\(y)-\(scale).\(format)"
        if !fileManager.fileExists(atPath: fileName) {
            let scaleString: String
            if scale == 1 {
                scaleString = ""
            } else {
                scaleString = "@\(scale)x"
            }
            let tileURL = "\(tileServerURL)/styles/\(style)/\(z)/\(x)/\(y)\(scaleString).\(format)"
            try downloadFile(from: tileURL, to: fileName)
            tileHitRatioLock.lock()
            tileHitRatio[style] = (hit: tileHitRatio[style]?.hit ?? 0, miss: (tileHitRatio[style]?.miss ?? 0) + 1)
            tileHitRatioLock.unlock()
        } else {
            touch(fileName: fileName)
            tileHitRatioLock.lock()
            tileHitRatio[style] = (hit: (tileHitRatio[style]?.hit ?? 0) + 1, miss: tileHitRatio[style]?.miss ?? 0)
            tileHitRatioLock.unlock()
        }
        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        Log.info("Serving Tile: \(style)-\(z)-\(x)-\(y)-\(scale).\(format)")
        try response.send(fileName: fileName)
    }
    
    private func getStatic(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        guard
            let style = request.parameters["style"],
            let lat = Double(request.parameters["lat"] ?? ""),
            let lon = Double(request.parameters["lon"] ?? ""),
            let zoom = UInt8(request.parameters["zoom"] ?? ""),
            let width = UInt16(request.parameters["width"] ?? ""),
            let height = UInt16(request.parameters["height"] ?? ""),
            let scale = UInt8(request.parameters["scale"] ?? ""),
            let orientation = UInt8(request.parameters["orientation"] ?? ""),
            let tilt = UInt8(request.parameters["tilt"] ?? ""),
            scale >= 1,
            let format = request.parameters["format"],
            format == "png" || format == "jpg" else {
                throw RequestError.badRequest
        }

        let fileManager = FileManager()
        let fileName = "\(FileKit.projectFolder)/Cache/Static/\(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(scale).\(format)"
        if !fileManager.fileExists(atPath: fileName) {
            Log.info("Loading Static: \(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(scale).\(format)")
            let scaleString: String
            if scale == 1 {
                scaleString = ""
            } else {
                scaleString = "@\(scale)x"
            }
            
            let tileURL = "\(tileServerURL)/styles/\(style)/static/\(lon),\(lat),\(zoom)@\(orientation),\(tilt)/\(width)x\(height)\(scaleString).\(format)"
            try downloadFile(from: tileURL, to: fileName)
            staticHitRatioLock.lock()
            staticHitRatio[style] = (hit: staticHitRatio[style]?.hit ?? 0, miss: (staticHitRatio[style]?.miss ?? 0) + 1)
            staticHitRatioLock.unlock()
        } else {
            touch(fileName: fileName)
            staticHitRatioLock.lock()
            staticHitRatio[style] = (hit: (staticHitRatio[style]?.hit ?? 0) + 1, miss: staticHitRatio[style]?.miss ?? 0)
            staticHitRatioLock.unlock()
        }

        var drawables = [Drawable]()
        if let polygonsJSONString = request.queryParameters["polygons"]?.removingPercentEncoding ?? request.queryParameters["polygons"],
           let polygonsJSONData = polygonsJSONString.data(using: .utf8),
           let polygons = try? JSONDecoder().decode([Polygon].self, from: polygonsJSONData),
           !polygons.isEmpty {
            drawables += polygons
        }
        if let markersJSONString = request.queryParameters["markers"]?.removingPercentEncoding ?? request.queryParameters["markers"],
           let markersJSONData = markersJSONString.data(using: .utf8),
           let markers = try? JSONDecoder().decode([Marker].self, from: markersJSONData),
           !markers.isEmpty {
            drawables += markers
        }
    
        
        if !drawables.isEmpty {
            
            let hashes = drawables.map { (drawable) -> String in
                return drawable.hashString
            }
            let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticWithMarkers/\(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(hashes.joined(separator: ","))-\(scale).\(format)"
            if !fileManager.fileExists(atPath: fileNameWithMarker) {
                var hashes = ""
                var fileNameWithMarkerFull = fileName
                for drawable in drawables {
                    hashes += drawable.hashString
                    let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticWithMarkers/\(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(hashes)-\(scale).\(format)"
                    
                    if !fileManager.fileExists(atPath: fileNameWithMarker) {
                        Log.info("Building Static: \(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(hashes)-\(scale).\(format)")
                        
                        if let marker = drawable as? Marker {
                            guard let markerURLEncoded = marker.url.data(using: .utf8)?.base64EncodedString() else {
                                Log.error("Failed to base 64 encode marker url")
                                throw RequestError.internalServerError
                            }
                            let markerFileName = "\(FileKit.projectFolder)/Cache/Marker/\(markerURLEncoded)"
                            if !fileManager.fileExists(atPath: markerFileName) {
                                Log.info("Loading Marker: \(marker.url)")
                                try downloadFile(from: marker.url, to: markerFileName)
                                markerHitRatioLock.lock()
                                markerHitRatio.miss += 1
                                markerHitRatioLock.unlock()
                            } else {
                                touch(fileName: fileName)
                                markerHitRatioLock.lock()
                                markerHitRatio.hit += 1
                                markerHitRatioLock.unlock()
                            }
                            try combineImages(staticPath: fileNameWithMarkerFull, markerPath: markerFileName, destinationPath: fileNameWithMarker, marker: marker, scale: scale, centerLat: lat, centerLon: lon, zoom: zoom)
                        } else if let polygon = drawable as? Polygon {
                            try drawPolygon(staticPath: fileNameWithMarkerFull, destinationPath: fileNameWithMarker, polygon: polygon, scale: scale, centerLat: lat, centerLon: lon, zoom: zoom, width: width, height: height)
                        }
                        staticMarkerHitRatioLock.lock()
                        staticMarkerHitRatio[style] = (hit: staticMarkerHitRatio[style]?.hit ?? 0, miss: (staticMarkerHitRatio[style]?.miss ?? 0) + 1)
                        staticMarkerHitRatioLock.unlock()
                    } else {
                        touch(fileName: fileName)
                        staticMarkerHitRatioLock.lock()
                        staticMarkerHitRatio[style] = (hit: (staticMarkerHitRatio[style]?.hit ?? 0) + 1, miss: staticMarkerHitRatio[style]?.miss ?? 0)
                        staticMarkerHitRatioLock.unlock()
                    }

                    hashes += ","
                    fileNameWithMarkerFull = fileNameWithMarker
                }
            } else {
                touch(fileName: fileName)
                staticMarkerHitRatioLock.lock()
                staticMarkerHitRatio[style] = (hit: (staticMarkerHitRatio[style]?.hit ?? 0) + 1, miss: staticMarkerHitRatio[style]?.miss ?? 0)
                staticMarkerHitRatioLock.unlock()
            }
            
            response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
            Log.info("Serving Static: \(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(hashes.joined(separator: ","))-\(scale).\(format)")
            try response.send(fileName: fileNameWithMarker)
        } else {
            response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
            Log.info("Serving Static: \(style)-\(lat)-\(lon)-\(zoom)-\(orientation)-\(tilt)-\(width)-\(height)-\(scale).\(format)")
            try response.send(fileName: fileName)
        }
    }
    
    private func getRoot(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        
        var tileCacheHitRateHTML = ""
        tileHitRatioLock.lock()
        for style in tileHitRatio {
            let hit = style.value.hit
            let total = style.value.miss + style.value.hit
            let precentage = UInt16(Double(hit) / Double(total) * 100)
            tileCacheHitRateHTML += """
            <h3 align="center">\(style.key): \(hit)/\(total) (\(precentage)%)</h3>
            """
        }
        tileHitRatioLock.unlock()
        
        var staticCacheHitRateHTML = ""
        staticHitRatioLock.lock()
        for style in staticHitRatio {
            let hit = style.value.hit
            let total = style.value.miss + style.value.hit
            let precentage = UInt16(Double(hit) / Double(total) * 100)
            staticCacheHitRateHTML += """
            <h3 align="center">\(style.key): \(hit)/\(total) (\(precentage)%)</h3>
            """
        }
        staticHitRatioLock.unlock()
        
        var staticMarkerCacheHitRatioHTML = ""
        staticMarkerHitRatioLock.lock()
        for style in staticMarkerHitRatio {
            let hit = style.value.hit
            let total = style.value.miss + style.value.hit
            let precentage = UInt16(Double(hit) / Double(total) * 100)
            staticMarkerCacheHitRatioHTML += """
            <h3 align="center">\(style.key): \(hit)/\(total) (\(precentage)%)</h3>
            """
        }
        staticMarkerHitRatioLock.unlock()
        
        var markerCacheHitRatioHTML = ""
        markerHitRatioLock.lock()
        if markerHitRatio.hit != 0 || markerHitRatio.miss != 0 {
            let hit = markerHitRatio.hit
            let total = markerHitRatio.miss + markerHitRatio.hit
            let precentage = UInt16(Double(hit) / Double(total) * 100)
            markerCacheHitRatioHTML += """
            <h3 align="center">Total: \(hit)/\(total) (\(precentage)%)</h3>
            """
        }
        markerHitRatioLock.unlock()
        
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8"/>
            <title>SwiftTileserver Cache</title>
        </head>
        <body>
            <h1 align="center">Swift Tileserver Cache</h1><br>
            <br><h2 align="center">Tiles Cache Hit-Rate (since restart)</h2>
            \(tileCacheHitRateHTML)
            <br><h2 align="center">Static Map Cache Hit-Rate (since restart)</h2>
            \(staticCacheHitRateHTML)
            <br><h2 align="center">Static Map with Marker Cache Hit-Rate (since restart)</h2>
            \(staticMarkerCacheHitRatioHTML)
            <br><h2 align="center">Marker Cache Hit-Rate (since restart)</h2>
            \(markerCacheHitRatioHTML)
        </body>
        """
        response.headers.setType("html", charset: "UTF-8")
        response.send(html)
    }

    private func downloadFile(from: String, to: String) throws {
        guard let fromURL = URL(string: from) else {
            Log.error("\(from) is not a valid url")
            throw RequestError.internalServerError
        }
        let toURL = URL(fileURLWithPath: to)
        let semaphore = DispatchSemaphore(value: 0)
        var errorToThrow: Error?
        let task = URLSession.shared.dataTask(with: fromURL) { (data, response, error) in
            if let data = data {
                do {
                    try data.write(to: toURL)
                } catch {
                    Log.error("Failed to save data to \(to): \(error)")
                    errorToThrow = RequestError.internalServerError
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 404 {
                    Log.info("Failed to load file. Got 404")
                    errorToThrow = RequestError.notFound
                } else {
                    Log.error("Failed to load file. Got \(response.statusCode)")
                    errorToThrow = RequestError.internalServerError
                }
            } else {
                Log.error("Failed to load file. No status code")
                errorToThrow = RequestError.internalServerError
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        if let error = errorToThrow {
            throw error
        }
    }
    
    private func combineImages(staticPath: String, markerPath: String, destinationPath: String, marker: Marker, scale: UInt8, centerLat: Double, centerLon: Double, zoom: UInt8) throws {
        
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
    
    private func drawPolygon(staticPath: String, destinationPath: String, polygon: Polygon, scale: UInt8, centerLat: Double, centerLon: Double, zoom: UInt8, width: UInt16, height: UInt16) throws {
     
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
    
    private func getRealOffset(at: Coordinate, relativeTo center: Coordinate, zoom: UInt8, scale: UInt8, extraX: Int16, extraY: Int16) -> (x: Int, y: Int) {
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
    
    private func touch(fileName: String) {
        do {
            var url = URL(fileURLWithPath: fileName)
            var resourceValues = URLResourceValues()
            resourceValues.contentAccessDate = Date()
            try url.setResourceValues(resourceValues)
        } catch {
            Log.warning("Failed to touch \(fileName): \(error)")
        }
    }
}
