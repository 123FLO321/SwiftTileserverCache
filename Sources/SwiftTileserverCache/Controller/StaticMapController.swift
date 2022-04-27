//
//  StaticMapController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor
import Leaf

internal class StaticMapController {
    
    private let tileServerURL: String
    private let tileController: TileController
    private let statsController: StatsController
    private let stylesController: StylesController

    private let sphericalMercator = SphericalMercator()

    init(tileServerURL: String, tileController: TileController, statsController: StatsController, stylesController: StylesController) {
        self.tileServerURL = tileServerURL
        self.tileController = tileController
        self.statsController = statsController
        self.stylesController = stylesController
    }
    
    // MARK: - Routes
    
    internal func get(request: Request) throws -> EventLoopFuture<Response> {
        let staticMap = try request.query.decode(StaticMap.self)
        return handleRequest(request: request, staticMap: staticMap)
    }

    internal func post(request: Request) throws -> EventLoopFuture<Response> {
         let staticMap = try request.content.decode(StaticMap.self)
         return handleRequest(request: request, staticMap: staticMap)
     }
    
    internal func getTemplate(request: Request) throws -> EventLoopFuture<Response> {
        guard let template = request.parameters.get("template") else {
            throw Abort(.badRequest, reason: "Missing template")
        }
        let context = try request.query.decode([String: LeafData].self)
        return handleRequest(request: request, template: template, context: context)
    }

    internal func postTemplate(request: Request) throws -> EventLoopFuture<Response> {
        guard let template = request.parameters.get("template") else {
            throw Abort(.badRequest, reason: "Missing template")
        }
        let context = try request.content.decode([String: LeafData].self)
        return handleRequest(request: request, template: template, context: context)
    }
    
    internal func getPregenerated(request: Request) throws -> EventLoopFuture<Response> {
        guard let id = request.parameters.get("id"), !id.contains("..") else {
            throw Abort(.badRequest, reason: "Missing id")
        }
        return handleRequest(request: request, id: id)
    }

    // MARK: - Interface
    
    internal func generateStaticMap(request: Request, staticMap: StaticMap) -> EventLoopFuture<Void> {
        let path = staticMap.path
        guard !FileManager.default.fileExists(atPath: path) else {
            return request.eventLoop.future()
        }
        return self.generateStaticMap(request: request, path: path, staticMap: staticMap)
    }
    
    // MARK: - Utils
    
    internal func handleRequest(request: Request, staticMap: StaticMap) -> EventLoopFuture<Response> {
        let path = staticMap.path
        if !FileManager.default.fileExists(atPath: path) {
            return generateStaticMapAndResponse(request: request, path: path, staticMap: staticMap).always { result in
                if case .success = result {
                    request.application.logger.info("Served a generated static map")
                    self.statsController.staticMapServed(new: true, path: path, style: staticMap.style)
                }
            }
        } else {
            return ResponseUtils.generateResponse(request: request, staticMap: staticMap, path: path).always { result in
                if case .success = result {
                    request.application.logger.info("Served a cached static map")
                    self.statsController.staticMapServed(new: false, path: path, style: staticMap.style)
                }
            }
        }
    }
    
    private func handleRequest(request: Request, id: String) -> EventLoopFuture<Response> {
        let path = "Cache/Static/\(id)"
        guard FileManager.default.fileExists(atPath: path) else {
            let regeneratablePath = "Cache/Regeneratable/\(path.components(separatedBy: "/").last!).json"
            guard FileManager.default.fileExists(atPath: regeneratablePath) else {
                return request.eventLoop.makeFailedFuture(Abort(.notFound, reason: "No regeneratable found with this id"))
            }
            return ResponseUtils.readRegeneratable(request: request, path: regeneratablePath, as: StaticMap.self).flatMap { staicMap in
                return self.generateStaticMapAndResponse(request: request, path: path, staticMap: staicMap)
            }
        }
        let staticMap: StaticMap? = nil
        return ResponseUtils.generateResponse(request: request, staticMap: staticMap, path: path).always { result in
            if case .success = result {
                request.application.logger.info("Served a pregenerate static map")
            }
        }
    }
    
    private func handleRequest(request: Request, template: String, context: [String: LeafData]) -> EventLoopFuture<Response> {
        return request.leaf.render(path: "Templates/\(template).json", context: context).flatMap { buffer in
            var bufferVar = buffer
            do {
                guard let staticMap = try bufferVar.readJSONDecodable(StaticMap.self, length: buffer.readableBytes) else {
                    throw Abort(.badRequest, reason: "Failed to decode json")
                }
                return self.handleRequest(request: request, staticMap: staticMap)
            } catch {
                var bufferError = buffer
                let string = bufferError.readString(length: bufferVar.readableBytes) ?? ""
                let reason = "Template \(template) Invalid (\(error.localizedDescription))"
                request.application.logger.error("\(reason)\n\(string)")
                return request.eventLoop.future(error: Abort(.internalServerError, reason: reason))
            }
        }
    }
    
    private func generateStaticMapAndResponse(request: Request, path: String, staticMap: StaticMap) -> EventLoopFuture<Response> {
        return generateStaticMap(request: request, path: path, staticMap: staticMap).flatMap {
            return ResponseUtils.generateResponse(request: request, staticMap: staticMap, path: path)
        }
    }
    
    private func generateStaticMap(request: Request, path: String, staticMap: StaticMap) -> EventLoopFuture<Void> {
        var baseStaticMap = staticMap
        baseStaticMap.markers = nil
        baseStaticMap.polygons = nil
        baseStaticMap.circles = nil
        let basePath = baseStaticMap.path
        
        if !FileManager.default.fileExists(atPath: basePath) {
            return loadBaseStaticMap(request: request, path: basePath, staticMap: baseStaticMap).flatMap {
                return self.generateFilledStaticMap(request: request, basePath: basePath, path: path, staticMap: staticMap)
            }
        } else {
            return self.generateFilledStaticMap(request: request, basePath: basePath, path: path, staticMap: staticMap)
        }
    }
    
    private func loadBaseStaticMap(request: Request, path: String, staticMap: StaticMap) -> EventLoopFuture<Void> {
        if let url = stylesController.getExternalStyle(name: staticMap.style)?.url {
            let hasScale = url.contains("{@scale}") || url.contains("{scale}")
            return generateBaseStaticMap(request: request, path: path, staticMap: staticMap, hasScale: hasScale)
        }

        let scaleString: String
        if staticMap.scale <= 1 {
            scaleString = ""
        } else {
            scaleString = "@\(staticMap.scale)x"
        }
        let tileURL = "\(tileServerURL)/styles/\(staticMap.style)/static/\(staticMap.longitude),\(staticMap.latitude),\(staticMap.zoom)@\(staticMap.bearing ?? 0),\(staticMap.pitch ?? 0)/\(staticMap.width)x\(staticMap.height)\(scaleString).\(staticMap.format ?? ImageFormat.png)"
        return APIUtils.downloadFile(request: request, from: tileURL, to: path, type: "image").flatMapError { error in
            return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load base static map: (\(error.localizedDescription))"))
        }
    }

    private func generateBaseStaticMap(request: Request, path: String, staticMap: StaticMap, hasScale: Bool) -> EventLoopFuture<Void> {
        let point = sphericalMercator.xy(coord: .init(latitude: staticMap.latitude, longitude: staticMap.longitude), zoom: Int(staticMap.zoom))
        let xOffsetLeft = max(0, Int(ceil((Double(staticMap.width) - Double(point.xDelta)) / 256)))
        let xOffsetRight = max(0, Int(ceil((Double(staticMap.width) - (256 - Double(point.xDelta))) / 256)))
        let yOffsetLeft = max(0, Int(ceil((Double(staticMap.height) - Double(point.yDelta)) / 256)))
        let yOffsetRight = max(0, Int(ceil((Double(staticMap.height) - (256 - Double(point.yDelta))) / 256)))
        var futures = [EventLoopFuture<String>]()
        for xOffset in -xOffsetLeft...xOffsetRight {
            for yOffset in -yOffsetLeft...yOffsetRight {
                futures.append(tileController.generateTile(
                    request: request,
                    style: staticMap.style,
                    z: Int(staticMap.zoom),
                    x: point.x + xOffset,
                    y: point.y + yOffset,
                    scale: staticMap.scale,
                    format: staticMap.format ?? ImageFormat.png
                ))
            }
        }

        return request.eventLoop.flatten(futures).flatMap( { tilePaths in
            return ImageUtils.generateBaseStaticMap(
                request: request,
                staticMap: staticMap,
                tilePaths: tilePaths,
                path: path,
                offsetX: Int(point.xDelta) + xOffsetLeft * 256,
                offsetY: Int(point.yDelta) + yOffsetLeft * 256,
                hasScale: hasScale
            )
        })
    }
    
    private func generateFilledStaticMap(request: Request, basePath: String, path: String, staticMap: StaticMap) -> EventLoopFuture<Void> {
        var drawables = [Drawable]()
        if let polygons = staticMap.polygons {
            drawables += polygons
        }
        if let circles = staticMap.circles {
            drawables += circles
        }
        if let markers = staticMap.markers {
            drawables += markers
        }
        guard !drawables.isEmpty else {
            return request.eventLoop.future()
        }
        
        var markerFutures = [EventLoopFuture<Void>]()
        for marker in staticMap.markers ?? [] {
            markerFutures.append(loadMarker(request: request, marker: marker))
        }
        return markerFutures.flatten(on: request.eventLoop).flatMap {
            return ImageUtils.generateStaticMap(request: request, staticMap: staticMap, basePath: basePath, path: path, sphericalMercator: self.sphericalMercator)
        }
    }

    private func loadMarker(request: Request, marker: Marker) -> EventLoopFuture<Void> {
        var future = loadMarker(request: request, url: marker.url)
        if let fallbackUrl = marker.fallbackUrl {
            future = future.flatMapError { error in
                self.loadMarker(request: request, url: fallbackUrl)
            }
        }
        return future
    }

    private func loadMarker(request: Request, url: String) -> EventLoopFuture<Void> {
        if url.starts(with: "http://") || url.starts(with: "https://") {
            guard URL(string: url) != nil else {
                return request.eventLoop.future(error: Abort(.badRequest, reason: "Marker url is not valid: \(url)"))
            }
            let markerHashed = url.persistentHash
            let markerFormat = url.components(separatedBy: ".").last ?? "png"
            let path = "Cache/Marker/\(markerHashed).\(markerFormat)"
            let domain = url.components(separatedBy: "//").last?.components(separatedBy: "/").first ?? "?"
            guard !FileManager.default.fileExists(atPath: path) else {
                statsController.markerServed(new: false, path: path, domain: domain)
                return request.eventLoop.future()
            }
            return APIUtils.downloadFile(request: request, from: url, to: path, type: "image").always { result in
                if case .success = result {
                    self.statsController.markerServed(new: true, path: path, domain: domain)
                }
            }.flatMapError { error in
                return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load marker: \(url) (\(error.localizedDescription))"))
            }
        } else {
            let path = "Markers/\(url)"
            guard !path.contains("..") else {
                return request.eventLoop.future(error: Abort(.badRequest, reason: "Path is not allowed to contain \"..\""))
            }
            guard FileManager.default.fileExists(atPath: path) else {
                return request.eventLoop.future(error: Abort(.notFound, reason: "Marker not found"))
            }
            return request.eventLoop.future()
        }
    }

}
