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
    
    private let router: Router
    private let tileServerURL: String
    
    public init(tileServerURL: String, port: Int=9000) {
        router = Router()
        self.tileServerURL = tileServerURL
        
        router.get("/tile/:style/:z/:x/:y/:scale/:format", handler: getTile)
        router.get("/static/:style/:lat/:lon/:zoom/:width:/:height/:scale:/:format", handler: getStatic)
        
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
        } else {
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileName)
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
            scale >= 1,
            let format = request.parameters["format"],
            format == "png" || format == "jpg" else {
                throw RequestError.badRequest
        }

        let fileManager = FileManager()
        let fileName = "\(FileKit.projectFolder)/Cache/Static/\(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(scale).\(format)"
        if !fileManager.fileExists(atPath: fileName) {
            Log.info("Loading Static: \(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(scale).\(format)")
            let scaleString: String
            if scale == 1 {
                scaleString = ""
            } else {
                scaleString = "@\(scale)x"
            }
            
            let tileURL = "\(tileServerURL)/styles/\(style)/static/\(lon),\(lat),\(zoom)/\(width)x\(height)\(scaleString).\(format)"
            try downloadFile(from: tileURL, to: fileName)
        } else {
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileName)
        }

        if let markersJSONString = request.queryParameters["markers"]?.removingPercentEncoding,
           let markersJSONData = markersJSONString.data(using: .utf8),
           let markers = try? JSONDecoder().decode([Marker].self, from: markersJSONData),
           !markers.isEmpty {
            
            let hashes = markers.map { (marker) -> String in
                return marker.hashValue.description
            }
            let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticWithMarkers/\(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(hashes.joined(separator: ","))-\(scale).\(format)"
            if !fileManager.fileExists(atPath: fileNameWithMarker) {
                var hashes = ""
                var fileNameWithMarkerFull = fileName
                for marker in markers {
                    hashes += marker.hashValue.description
                    let fileNameWithMarker = "\(FileKit.projectFolder)/Cache/StaticWithMarkers/\(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(hashes)-\(scale).\(format)"
                    
                    if !fileManager.fileExists(atPath: fileNameWithMarker) {
                        Log.info("Building Static: \(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(hashes)-\(scale).\(format)")
                        guard let markerURLEncoded = marker.url.data(using: .utf8)?.base64EncodedString() else {
                            Log.error("Failed to base 64 encode marker url")
                            throw RequestError.internalServerError
                        }
                        let markerFileName = "\(FileKit.projectFolder)/Cache/Marker/\(markerURLEncoded)"
                        if !fileManager.fileExists(atPath: markerFileName) {
                            Log.info("Loading Marker: \(marker.url)")
                            try downloadFile(from: marker.url, to: markerFileName)
                        } else {
                            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: markerFileName)
                        }
                        try combineImages(staticPath: fileNameWithMarkerFull, markerPath: markerFileName, destinationPath: fileNameWithMarker, marker: marker, scale: scale, centerLat: lat, centerLon: lon, zoom: zoom)
                    } else {
                        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileNameWithMarker)
                    }
            
                    hashes += ","
                    fileNameWithMarkerFull = fileNameWithMarker
                }
            } else {
                try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileNameWithMarker)
            }
            
            response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
            Log.info("Serving Static: \(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(hashes.joined(separator: ","))-\(scale).\(format)")
            try response.send(fileName: fileNameWithMarker)
        } else {
            response.headers["Cache-Control"] = "max-age=604800, must-revalidate"
            Log.info("Serving Static: \(style)-\(lat)-\(lon)-\(zoom)-\(width)-\(height)-\(scale).\(format)")
            try response.send(fileName: fileName)
        }
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
            scale: scale
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
    
    private func getRealOffset(at: Coordinate, relativeTo center: Coordinate, zoom: UInt8, scale: UInt8) -> (x: Int, y: Int) {
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
        return (realOffsetX, realOffsetY)
    }
}
