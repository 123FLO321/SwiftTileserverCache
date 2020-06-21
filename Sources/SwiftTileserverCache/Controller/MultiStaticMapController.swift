//
//  MultiStaticMapController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor
import Leaf

internal class MultiStaticMapController {

    private let staticMapController: StaticMapController
    private let statsController: StatsController

    internal init(staticMapController: StaticMapController, statsController: StatsController) {
        self.staticMapController = staticMapController
        self.statsController = statsController
    }

    // MARK: - Routes

    internal func get(request: Request) throws -> EventLoopFuture<Response> {
        let multiStaticMap = try request.query.decode(MultiStaticMap.self)
        return handleRequest(request: request, multiStaticMap: multiStaticMap)
    }

    internal func post(request: Request) throws -> EventLoopFuture<Response> {
        let multiStaticMap = try request.content.decode(MultiStaticMap.self)
        return handleRequest(request: request, multiStaticMap: multiStaticMap)
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

    // MARK: - Utils

    private func handleRequest(request: Request, multiStaticMap: MultiStaticMap) -> EventLoopFuture<Response> {
        let path = multiStaticMap.path
        if !FileManager.default.fileExists(atPath: path) {
            return generateStaticMapAndResponse(request: request, path: path, multiStaticMap: multiStaticMap).always {_ in
                request.application.logger.info("Served a generated multi-static map")
                self.statsController.staticMapServed(new: true, path: path, style: "multi")
            }
        } else {
            return ResponseUtils.generateResponse(request: request, staticMap: multiStaticMap, path: path).always {_ in
                request.application.logger.info("Served a cached multi-static map")
                self.statsController.staticMapServed(new: false, path: path, style: "multi")
            }
        }
    }

    private func handleRequest(request: Request, id: String) -> EventLoopFuture<Response> {
        let path = "Cache/StaticMulti/\(id)"
        guard FileManager.default.fileExists(atPath: path) else {
            let regeneratablePath = "Cache/Regeneratable/\(path.components(separatedBy: "/").last!).json"
            guard FileManager.default.fileExists(atPath: regeneratablePath) else {
                return request.eventLoop.makeFailedFuture(Abort(.notFound, reason: "No regeneratable found with this id"))
            }
            return ResponseUtils.readRegeneratable(request: request, path: regeneratablePath, as: MultiStaticMap.self).flatMap { multiStaticMap in
                return self.generateStaticMapAndResponse(request: request, path: path, multiStaticMap: multiStaticMap)
            }
        }
        let staticMap: StaticMap? = nil
        return ResponseUtils.generateResponse(request: request, staticMap: staticMap, path: path).always {_ in
            request.application.logger.info("Served a pregenerate multi-static map")
        }
    }

    private func handleRequest(request: Request, template: String, context: [String: LeafData]) -> EventLoopFuture<Response> {
        return request.leaf.render(path: "../../Templates/\(template).json", context: context).flatMap { buffer in
            var bufferVar = buffer
            do {
                guard let multiStaticMap = try bufferVar.readJSONDecodable(MultiStaticMap.self, length: buffer.readableBytes) else {
                    throw Abort(.badRequest, reason: "Failed to decode json")
                }
                return self.handleRequest(request: request, multiStaticMap: multiStaticMap)
            } catch {
                var bufferError = buffer
                let string = bufferError.readString(length: bufferVar.readableBytes) ?? ""
                let reason = "Template Invalid (\(error.localizedDescription)) [\(string)]"
                return request.eventLoop.future(error: Abort(.internalServerError, reason: reason))
            }
        }
    }

    private func generateStaticMapAndResponse(request: Request, path: String, multiStaticMap: MultiStaticMap) -> EventLoopFuture<Response> {
        let maps = multiStaticMap.grid.flatMap { (gridMap) -> [StaticMap] in
            return gridMap.maps.map { (map) -> StaticMap in
                return map.map
            }
        }
        let mapFutures = maps.map { (map) -> EventLoopFuture<Void> in
            return staticMapController.generateStaticMap(request: request, staticMap: map)
        }
        return request.eventLoop.flatten(mapFutures).flatMap {
            return ImageUtils.generateMultiStaticMap(request: request, multiStaticMap: multiStaticMap, path: path).flatMap {
                return ResponseUtils.generateResponse(request: request, staticMap: multiStaticMap, path: path)
            }
        }
    }

}
