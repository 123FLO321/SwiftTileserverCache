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
import PathKit
import Stencil
import Cryptor

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
        router.get("/styles", handler: getStyles)
        router.get("/tile/:style/:z/:x/:y/:scale/:format", handler: getTile)

        router.get("/staticmap/:template", handler: getStaticMapTemplate)
        router.get("/staticmap", handler: getStaticMap)
        router.post("/staticmap", handler: postStaticMap)

        router.get("/multistaticmap/:template", handler: getMultiStaticMapTemplate)
        router.post("/multistaticmap", handler: postMultiStaticMap)

        router.get("/static/:style/:lat/:lon/:zoom/:width:/:height/:scale:/:format", handler: getStatic)
        
        Kitura.addHTTPServer(onPort: port, with: router)
        Kitura.start()
    }

    // MARK: - Routes

    // get "/"
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

    // get "/styles"
    private func getStyles(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        let stylesURL = "\(tileServerURL)/styles.json"
        let styles: [Style] = try APIUtils.loadJSON(from: stylesURL)
        var returnArray = [String]()
        for style in styles {
            returnArray.append(style.id)
        }
        response.send(returnArray)
    }

    // get "/tile/:style/:z/:x/:y/:scale/:format"
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
            try APIUtils.downloadFile(from: tileURL, to: fileName)
            tileHitRatioLock.lock()
            tileHitRatio[style] = (hit: tileHitRatio[style]?.hit ?? 0, miss: (tileHitRatio[style]?.miss ?? 0) + 1)
            tileHitRatioLock.unlock()
        } else {
            touch(fileManager: fileManager, fileName: fileName)
            tileHitRatioLock.lock()
            tileHitRatio[style] = (hit: (tileHitRatio[style]?.hit ?? 0) + 1, miss: tileHitRatio[style]?.miss ?? 0)
            tileHitRatioLock.unlock()
        }
        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        Log.info("Serving Tile: \(style)-\(z)-\(x)-\(y)-\(scale).\(format)")
        try response.send(fileName: fileName)
    }

    // get "/staticmap/:template"
    private func getStaticMapTemplate(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        let environment = Environment(loader: FileSystemLoader(paths: [Path("\(FileKit.projectFolder)/Templates")]))
        let fileName: String
        do {
            var context = [String: Any]()
            for param in request.queryParametersMultiValues {
                if param.value.count == 1 {
                    if param.key.lowercased().hasSuffix("json"), let data = param.value[0].data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) {
                        context[param.key] = json
                    } else {
                        context[param.key] = param.value[0]
                    }
                } else {
                    context[param.key] = param.value
                }
            }
            let rendered = try environment.renderTemplate(name: "\(request.parameters["template"] ?? "" ).json", context: context)
            guard let data = rendered.data(using: .utf8) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Not utf8 encoded."))
            }
            let staticMap = try JSONDecoder().decode(StaticMap.self, from: data)
            fileName = try generateStaticMap(staticMap: staticMap)
        } catch let error as TemplateDoesNotExist {
            return try response.send(error.description).status(.badRequest).end()
        } catch let error as TemplateSyntaxError {
            return try response.send(error.reason).status(.badRequest).end()
        } catch let error as DecodingError {
            return try response.send(error.humanReadableDescription).status(.badRequest).end()
        } catch let error as RequestError {
            return try response.send(error.reason).status(HTTPStatusCode(rawValue: error.httpCode) ?? .internalServerError).end()
        } catch {
            return try response.send(error.localizedDescription).status(.badRequest).end()
        }

        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        try response.send(fileName: fileName)
    }

    // get "/staticmap"
    private func getStaticMap(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        guard let style = request.queryParameters["style"] else {
            return try response.send("Missing value for \"style\"").status(.badRequest).end()
        }
        guard let latitude = Double(request.queryParameters["latitude"] ?? "") else {
            return try response.send("Missing value for \"latitude\"").status(.badRequest).end()
        }
        guard let longitude = Double(request.queryParameters["longitude"] ?? "") else {
            return try response.send("Missing value for \"longitude\"").status(.badRequest).end()
        }
        guard let zoom = Double(request.queryParameters["zoom"] ?? "") else {
            return try response.send("Missing value for \"zoom\"").status(.badRequest).end()
        }
        guard let width = UInt16(request.queryParameters["width"] ?? "") else {
            return try response.send("Missing value for \"width\"").status(.badRequest).end()
        }
        guard let height = UInt16(request.queryParameters["height"] ?? "") else {
            return try response.send("Missing value for \"height\"").status(.badRequest).end()
        }
        guard let scale = UInt8(request.queryParameters["scale"] ?? "") else {
            return try response.send("Missing value for \"scale\"").status(.badRequest).end()
        }
        let format = request.queryParameters["format"]
        let bearing = Double(request.queryParameters["bearing"] ?? "")
        let pitch = Double(request.queryParameters["pitch"] ?? "")

        let polygons: [Polygon]?
        if let polygonsJSONString = request.queryParameters["polygons"]?.removingPercentEncoding ?? request.queryParameters["polygons"],
           let polygonsJSONData = polygonsJSONString.data(using: .utf8) {
            polygons = try? JSONDecoder().decode([Polygon].self, from: polygonsJSONData)
        } else {
            polygons = nil
        }

        let markers: [Marker]?
        if let markersJSONString = request.queryParameters["markers"]?.removingPercentEncoding ?? request.queryParameters["markers"],
           let markersJSONData = markersJSONString.data(using: .utf8) {
           markers = try? JSONDecoder().decode([Marker].self, from: markersJSONData)
        } else {
            markers = nil
        }

        let staticMap = StaticMap(style: style, latitude: latitude, longitude: longitude, zoom: zoom, width: width, height: height, scale: scale, format: format, bearing: bearing, pitch: pitch, markers: markers, polygons: polygons)

        let fileName: String
        do {
            fileName = try generateStaticMap(staticMap: staticMap)
        } catch let error as DecodingError {
            return try response.send(error.humanReadableDescription).status(.badRequest).end()
        } catch let error as RequestError {
            return try response.send(error.reason).status(HTTPStatusCode(rawValue: error.httpCode) ?? .internalServerError).end()
        } catch {
            return try response.send(error.localizedDescription).status(.badRequest).end()
        }

        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        try response.send(fileName: fileName)
    }

    // post "/staticmap"
    private func postStaticMap(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        let fileName: String
        do {
            let staticMap = try request.read(as: StaticMap.self)
            fileName = try generateStaticMap(staticMap: staticMap)
        } catch let error as DecodingError {
            return try response.send(error.humanReadableDescription).status(.badRequest).end()
        } catch let error as RequestError {
            return try response.send(error.reason).status(HTTPStatusCode(rawValue: error.httpCode) ?? .internalServerError).end()
        } catch {
            return try response.send(error.localizedDescription).status(.badRequest).end()
        }

        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        try response.send(fileName: fileName)
    }

    // get "/multistaticmap/:template"
    private func getMultiStaticMapTemplate(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        let environment = Environment(loader: FileSystemLoader(paths: [Path("\(FileKit.projectFolder)/Templates")]))
        let fileName: String
        do {
            var context = [String: Any]()
            for param in request.queryParametersMultiValues {
                if param.value.count == 1 {
                    if param.key.lowercased().hasSuffix("json"), let data = param.value[0].data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) {
                        context[param.key] = json
                    } else {
                        context[param.key] = param.value[0]
                    }
                } else {
                    context[param.key] = param.value
                }
            }
            let rendered = try environment.renderTemplate(name: "\(request.parameters["template"] ?? "" ).json", context: context)
            guard let data = rendered.data(using: .utf8) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Not utf8 encoded."))
            }
            let multiStaticMap = try JSONDecoder().decode(MultiStaticMap.self, from: data)
            fileName = try generateMultiStaticMap(multiStaticMap: multiStaticMap)
        } catch let error as TemplateDoesNotExist {
            return try response.send(error.description).status(.badRequest).end()
        } catch let error as TemplateSyntaxError {
            return try response.send(error.reason).status(.badRequest).end()
        } catch let error as DecodingError {
            return try response.send(error.humanReadableDescription).status(.badRequest).end()
        } catch let error as RequestError {
            return try response.send(error.reason).status(HTTPStatusCode(rawValue: error.httpCode) ?? .internalServerError).end()
        } catch {
            return try response.send(error.localizedDescription).status(.badRequest).end()
        }

        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        try response.send(fileName: fileName)
    }

    // post "/multistaticmap"
    private func postMultiStaticMap(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        let fileName: String
        do {
            let multiStaticMap = try request.read(as: MultiStaticMap.self)
            fileName = try generateMultiStaticMap(multiStaticMap: multiStaticMap)
        } catch let error as DecodingError {
            return try response.send(error.humanReadableDescription).status(.badRequest).end()
        } catch let error as RequestError {
            return try response.send(error.reason).status(HTTPStatusCode(rawValue: error.httpCode) ?? .internalServerError).end()
        } catch {
            return try response.send(error.localizedDescription).status(.badRequest).end()
        }

        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        try response.send(fileName: fileName)
    }

    // deprecated get "/static/:style/:lat/:lon/:zoom/:width:/:height/:scale:/:format"
    private func getStatic(request: RouterRequest, response: RouterResponse, next:  @escaping () -> Void) throws {
        Log.warning("\"/static/:style/:lat/:lon/:zoom/:width:/:height/:scale:/:format\" is deprecated and will be removed in future versions.")
        guard
            let style = request.parameters["style"],
            let lat = Double(request.parameters["lat"] ?? ""),
            let lon = Double(request.parameters["lon"] ?? ""),
            let zoom = Double(request.parameters["zoom"] ?? ""),
            let width = UInt16(request.parameters["width"] ?? ""),
            let height = UInt16(request.parameters["height"] ?? ""),
            let scale = UInt8(request.parameters["scale"] ?? ""),
            scale >= 1,
            let format = request.parameters["format"],
            format == "png" || format == "jpg" else {
                throw RequestError.badRequest
        }

        let polygons: [Polygon]?
        if let polygonsJSONString = request.queryParameters["polygons"]?.removingPercentEncoding ?? request.queryParameters["polygons"],
           let polygonsJSONData = polygonsJSONString.data(using: .utf8) {
            polygons = try? JSONDecoder().decode([Polygon].self, from: polygonsJSONData)
        } else {
            polygons = nil
        }

        let markers: [Marker]?
        if let markersJSONString = request.queryParameters["markers"]?.removingPercentEncoding ?? request.queryParameters["markers"],
           let markersJSONData = markersJSONString.data(using: .utf8) {
           markers = try? JSONDecoder().decode([Marker].self, from: markersJSONData)
        } else {
            markers = nil
        }


        let staticMap = StaticMap(style: style, latitude: lat, longitude: lon, zoom: zoom, width: width, height: height, scale: scale, format: format, bearing: nil, pitch: nil, markers: markers, polygons: polygons)
        let fileName = try generateStaticMap(staticMap: staticMap)
        response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
        try response.send(fileName: fileName)
    }

    // MARK: - Misc

    private func generateStaticMap(staticMap: StaticMap) throws -> String {
        let fileManager = FileManager()
        var staticMapNoMarkers = staticMap
        staticMapNoMarkers.markers = nil
        staticMapNoMarkers.polygons = nil
        let fileName = "\(FileKit.projectFolder)/Cache/Static/\(staticMapNoMarkers.uniqueHash).\(staticMap.format ?? "png")"
        if !fileManager.fileExists(atPath: fileName) {
            Log.info("Loading Static: \(staticMap)")
            let scaleString: String
            if staticMap.scale <= 1 {
                scaleString = ""
            } else {
                scaleString = "@\(staticMap.scale)x"
            }

            let tileURL = "\(tileServerURL)/styles/\(staticMap.style)/static/\(staticMap.longitude),\(staticMap.latitude),\(staticMap.zoom)@\(staticMap.bearing ?? 0),\(staticMap.pitch ?? 0)/\(staticMap.width)x\(staticMap.height)\(scaleString).\(staticMap.format ?? "png")"
            do {
                try APIUtils.downloadFile(from: tileURL, to: fileName)
            } catch {
                throw RequestError(rawValue: 400, reason: "Failed to load base staticmap")
            }
            staticHitRatioLock.lock()
            staticHitRatio[staticMap.style] = (hit: staticHitRatio[staticMap.style]?.hit ?? 0, miss: (staticHitRatio[staticMap.style]?.miss ?? 0) + 1)
            staticHitRatioLock.unlock()
        } else {
            touch(fileManager: fileManager, fileName: fileName)
            staticHitRatioLock.lock()
            staticHitRatio[staticMap.style] = (hit: (staticHitRatio[staticMap.style]?.hit ?? 0) + 1, miss: staticHitRatio[staticMap.style]?.miss ?? 0)
            staticHitRatioLock.unlock()
        }

        var drawables = [Drawable]()
        if let polygons = staticMap.polygons {
            drawables += polygons
        }
        if let markers = staticMap.markers {
            drawables += markers
        }

        if !drawables.isEmpty {
            var staticMapC = staticMap
            if staticMapC.polygons == nil {
                staticMapC.polygons = []
            }
            if staticMapC.markers == nil {
                staticMapC.markers = []
            }
            let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticWithMarkers/\(staticMapC.uniqueHash)).\(staticMapC.format ?? "png")"
            if !fileManager.fileExists(atPath: fileNameWithMarker) {
                var fileNameWithMarkerFull = fileName
                var addedPolygons = [Polygon]()
                var addedMarkers = [Marker]()
                for drawable in drawables {
                    if let marker = drawable as? Marker {
                        addedMarkers.append(marker)
                    } else if let polygon = drawable as? Polygon {
                        addedPolygons.append(polygon)
                    }

                    var staticMapCopy = staticMap
                    staticMapCopy.markers = addedMarkers
                    staticMapCopy.polygons = addedPolygons

                    let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticWithMarkers/\(staticMapCopy.uniqueHash)).\(staticMapCopy.format ?? "png")"

                    if !fileManager.fileExists(atPath: fileNameWithMarker) {
                        Log.info("Building Static: \(staticMap)")

                        if let marker = drawable as? Marker {
                            guard let markerHashedData = Digest(using: .md5).update(string: marker.url)?.final() else {
                                Log.error("Failed to hash marker url")
                                throw RequestError.internalServerError
                            }
                            let markerHashed = Data(markerHashedData).base64EncodedString().replacingOccurrences(of: "/", with: "_")
                            let markerFormat = marker.url.components(separatedBy: ".").last ?? "png"
                            let markerFileName = "\(FileKit.projectFolder)/Cache/Marker/\(markerHashed).\(markerFormat)"
                            if !fileManager.fileExists(atPath: markerFileName) {
                                Log.info("Loading Marker: \(marker.url)")
                                do {
                                    try APIUtils.downloadFile(from: marker.url, to: markerFileName)
                                } catch {
                                    throw RequestError(rawValue: 400, reason: "Failed to load marker: \(marker.url)")
                                }
                                markerHitRatioLock.lock()
                                markerHitRatio.miss += 1
                                markerHitRatioLock.unlock()
                            } else {
                                touch(fileManager: fileManager, fileName: fileName)
                                markerHitRatioLock.lock()
                                markerHitRatio.hit += 1
                                markerHitRatioLock.unlock()
                            }
                            try ImageUtils.combineImages(staticPath: fileNameWithMarkerFull, markerPath: markerFileName, destinationPath: fileNameWithMarker, marker: marker, scale: staticMap.scale, centerLat: staticMap.latitude, centerLon: staticMap.longitude, zoom: staticMap.zoom)
                        } else if let polygon = drawable as? Polygon {
                            try ImageUtils.drawPolygon(staticPath: fileNameWithMarkerFull, destinationPath: fileNameWithMarker, polygon: polygon, scale: staticMap.scale, centerLat: staticMap.latitude, centerLon: staticMap.longitude, zoom: staticMap.zoom, width: staticMap.width, height: staticMap.height)
                        }
                        staticMarkerHitRatioLock.lock()
                        staticMarkerHitRatio[staticMap.style] = (hit: staticMarkerHitRatio[staticMap.style]?.hit ?? 0, miss: (staticMarkerHitRatio[staticMap.style]?.miss ?? 0) + 1)
                        staticMarkerHitRatioLock.unlock()
                    } else {
                        touch(fileManager: fileManager, fileName: fileName)
                        staticMarkerHitRatioLock.lock()
                        staticMarkerHitRatio[staticMap.style] = (hit: (staticMarkerHitRatio[staticMap.style]?.hit ?? 0) + 1, miss: staticMarkerHitRatio[staticMap.style]?.miss ?? 0)
                        staticMarkerHitRatioLock.unlock()
                    }
                    fileNameWithMarkerFull = fileNameWithMarker
                }
            } else {
                touch(fileManager: fileManager, fileName: fileNameWithMarker)
                staticMarkerHitRatioLock.lock()
                staticMarkerHitRatio[staticMap.style] = (hit: (staticMarkerHitRatio[staticMap.style]?.hit ?? 0) + 1, miss: staticMarkerHitRatio[staticMap.style]?.miss ?? 0)
                staticMarkerHitRatioLock.unlock()
            }
            Log.info("Serving Static: \(staticMap)")
            return fileNameWithMarker
        } else {
            Log.info("Serving Static: \(staticMap)")
            return fileName
        }
    }

    private func generateMultiStaticMap(multiStaticMap: MultiStaticMap) throws -> String {
        guard multiStaticMap.grid.count >= 1 else {
            throw RequestError(rawValue: 400, reason: "At least one grid is required")
        }
        guard multiStaticMap.grid.first?.direction == .first else {
            throw RequestError(rawValue: 400, reason: "First grid requires direction: \"first\"")
        }
        for index in 1..<multiStaticMap.grid.count {
            if multiStaticMap.grid[index].direction == .first {
                throw RequestError(rawValue: 400, reason: "Only first gird is allowed to be direction: \"first\"")
            }
        }
        for grid in multiStaticMap.grid {
            guard grid.maps.first?.direction == .first else {
                throw RequestError(rawValue: 400, reason: "First map in grid requires direction: \"first\"")
            }
            for index in 1..<grid.maps.count {
                if grid.maps[index].direction == .first {
                    throw RequestError(rawValue: 400, reason: "Only first map in grid is allowed to be direction: \"first\"")
                }
            }
        }

        let fileManager = FileManager()
        let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticMulti/\(multiStaticMap.uniqueHash).png"
        var grids = [(firstPath: String, direction: CombineDirection, images: [(direction: CombineDirection, path: String)])]()
        if !fileManager.fileExists(atPath: fileNameWithMarker) {
            for grid in multiStaticMap.grid {
                var firstMapUrl = ""
                var images = [(CombineDirection, String)]()
                for map in grid.maps {
                    let url = try generateStaticMap(staticMap: map.map)
                    if map.direction == .first {
                        firstMapUrl = url
                    } else {
                        images.append((map.direction, url))
                    }
                }
                grids.append((firstMapUrl, grid.direction, images))
            }
            Log.info("Generating MutliStatic: \(multiStaticMap)")
            try ImageUtils.combineImages(grids: grids, destinationPath: fileNameWithMarker)
            Log.info("Serving MutliStatic: \(multiStaticMap)")
            return fileNameWithMarker
        } else {
            Log.info("Serving MutliStatic: \(multiStaticMap)")
            return fileNameWithMarker
        }
    }

    private func touch(fileManager: FileManager, fileName: String) {
        DispatchQueue(label: "Touch-\(UUID().uuidString)").async {
            do {
                #if os(macOS)
                try fileManager.setAttributes([.modificationDate : Date()], ofItemAtPath: fileName)
                #else
                let shell = Shell("/usr/bin/touch", fileName)
                let error = try shell.runError()
                if (error ?? "") != "" {
                    Log.warning("Failed to touch \(fileName): \(error!)")
                }
                #endif
            } catch {
                Log.warning("Failed to touch \(fileName): \(error)")
            }
        }
    }

}
