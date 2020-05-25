//
//  StaticMapController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor
import Leaf

internal struct StaticMapController {
    
    internal let tileServerURL: String
    internal let statsController: StatsController
    
    // MARK: - Routes
    
    internal func get(request: Request) throws -> EventLoopFuture<Response> {
        let staticMap = try request.query.decode(StaticMap.self)
        return handleRequest(request: request, staticMap: staticMap)
    }
    
    internal func getTemplate(request: Request) throws -> EventLoopFuture<Response> {
        guard let template = request.parameters.get("template") else {
            throw Abort(.badRequest, reason: "Missing template")
        }
        return handleRequest(request: request, template: template)
    }
    
    internal func getPregenerated(request: Request) throws -> EventLoopFuture<Response> {
        guard let id = request.parameters.get("id"), !id.contains("..") else {
            throw Abort(.badRequest, reason: "Missing id")
        }
        return handleRequest(request: request, id: id)
    }
    
    internal func post(request: Request) throws -> EventLoopFuture<Response> {
        let staticMap = try request.content.decode(StaticMap.self)
        return handleRequest(request: request, staticMap: staticMap)
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
    
    private func handleRequest(request: Request, staticMap: StaticMap) -> EventLoopFuture<Response> {
        let path = staticMap.path
        if !FileManager.default.fileExists(atPath: path) {
            return generateStaticMapAndResponse(request: request, path: path, staticMap: staticMap).always {_ in
                request.application.logger.info("Served a generated static map")
                self.statsController.staticMapServed(new: true, path: path, style: staticMap.style)
            }
        } else {
            return ResponseUtils.generateResponse(request: request, staticMap: staticMap, path: path).always {_ in
                request.application.logger.info("Served a cached static map")
                self.statsController.staticMapServed(new: false, path: path, style: staticMap.style)
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
        return ResponseUtils.generateResponse(request: request, staticMap: staticMap, path: path).always {_ in
            request.application.logger.info("Served a pregenerate static map")
        }
    }
    
    private func handleRequest(request: Request, template: String) -> EventLoopFuture<Response> {
        let context: [String: LeafData]
        do {
            context = try request.query.decode([String: LeafData].self)
        } catch {
            return request.eventLoop.future(error: error)
        }
        return request.leaf.render(path: "../../Templates/\(template).json", context: context).flatMap { buffer in
            var bufferVar = buffer
            do {
                guard let staticMap = try bufferVar.readJSONDecodable(StaticMap.self, length: buffer.readableBytes) else {
                    throw Abort(.badRequest, reason: "Failed to decode json")
                }
                return self.handleRequest(request: request, staticMap: staticMap)
            } catch {
                var bufferError = buffer
                let string = bufferError.readString(length: bufferVar.readableBytes) ?? ""
                let reason = "Template Invalid (\(error.localizedDescription)) [\(string)]"
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
        let basePath = baseStaticMap.path
        
        if !FileManager.default.fileExists(atPath: basePath) {
            return loadBaseStaticMap(request: request, path: basePath, staticMap: baseStaticMap).flatMap {
                return self.generateFilledStaticMap(request: request, basePath: basePath, path: path, staticMap: staticMap).always { _ in
                    self.statsController.staticMapServed(new: true, path: basePath, style: staticMap.style)
                }
            }
        } else {
            return self.generateFilledStaticMap(request: request, basePath: basePath, path: path, staticMap: staticMap).always { _ in
                self.statsController.staticMapServed(new: false, path: basePath, style: staticMap.style)
            }
        }
    }
    
    private func loadBaseStaticMap(request: Request, path: String, staticMap: StaticMap) -> EventLoopFuture<Void> {
        let scaleString: String
        if staticMap.scale <= 1 {
            scaleString = ""
        } else {
            scaleString = "@\(staticMap.scale)x"
        }
        
        let tileURL = "\(tileServerURL)/styles/\(staticMap.style)/static/\(staticMap.longitude),\(staticMap.latitude),\(staticMap.zoom)@\(staticMap.bearing ?? 0),\(staticMap.pitch ?? 0)/\(staticMap.width)x\(staticMap.height)\(scaleString).\(staticMap.format ?? "png")"
        return APIUtils.downloadFile(request: request, from: tileURL, to: path).flatMapError { error in
            return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load base static map: (\(error.localizedDescription))"))
        }
    }
    
    private func generateFilledStaticMap(request: Request, basePath: String, path: String, staticMap: StaticMap) -> EventLoopFuture<Void> {
        var drawables = [Drawable]()
        if let polygons = staticMap.polygons {
            drawables += polygons
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
            return ImageUtils.generateStaticMap(request: request, staticMap: staticMap, basePath: basePath, path: path)
        }
    }
    
    private func loadMarker(request: Request, marker: Marker) -> EventLoopFuture<Void> {
        if marker.url.starts(with: "http://") || marker.url.starts(with: "https://") {
            guard URL(string: marker.url) != nil else {
                return request.eventLoop.future(error: Abort(.badRequest, reason: "Marker url is not valid: \(marker.url)"))
            }
            let markerHashed = marker.url.persistentHash
            let markerFormat = marker.url.components(separatedBy: ".").last ?? "png"
            let path = "Cache/Marker/\(markerHashed).\(markerFormat)"
            let domain = marker.url.components(separatedBy: "//").last?.components(separatedBy: "/").first ?? "?"
            guard !FileManager.default.fileExists(atPath: path) else {
                statsController.markerServed(new: false, path: path, domain: domain)
                return request.eventLoop.future()
            }
            return APIUtils.downloadFile(request: request, from: marker.url, to: path).always { _ in
                self.statsController.markerServed(new: true, path: path, domain: domain)
            }.flatMapError { error in
                return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load marker: \(marker.url) (\(error.localizedDescription))"))
            }
        } else {
            let path = "Markers/\(marker.url)"
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
