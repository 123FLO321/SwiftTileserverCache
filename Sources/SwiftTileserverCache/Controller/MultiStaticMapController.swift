//
//  MultiStaticMapController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor
import Leaf

internal struct MultiStaticMapController {

    internal let tileServerURL: String
    internal let statsController: StatsController
    internal let staticMapController: StaticMapController

    // MARK: - Routes

    internal func get(request: Request) throws -> EventLoopFuture<Response> {
        let multiStaticMap = try request.query.decode(MultiStaticMap.self)
        return handleRequest(request: request, multiStaticMap: multiStaticMap)
    }

    internal func getTemplate(request: Request) throws -> EventLoopFuture<Response> {
        guard let template = request.parameters.get("template") else {
            throw Abort(.badRequest)
        }
        return handleRequest(request: request, template: template)
    }

    internal func getPregenerated(request: Request) throws -> EventLoopFuture<Response> {
        guard let id = request.parameters.get("id"), !id.contains("..") else {
            throw Abort(.badRequest)
        }
        return handleRequest(request: request, id: id)
    }

    internal func post(request: Request) throws -> EventLoopFuture<Response> {
        let multiStaticMap = try request.content.decode(MultiStaticMap.self)
        return handleRequest(request: request, multiStaticMap: multiStaticMap)
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
            return generateResponse(request: request, path: path).always {_ in
                request.application.logger.info("Served a cached multi-static map")
                self.statsController.staticMapServed(new: false, path: path, style: "multi")
            }
        }
    }

    private func handleRequest(request: Request, id: String) -> EventLoopFuture<Response> {
        let path = "Cache/StaticMulti/\(id)"
        guard FileManager.default.fileExists(atPath: path) else {
            return request.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        return generateResponse(request: request, path: path).always {_ in
            request.application.logger.info("Served a pregenerate multi-static map")
        }
    }

    private func handleRequest(request: Request, template: String) -> EventLoopFuture<Response> {
        let context: [String: LeafData]
        do {
            context = try request.query.decode([String: LeafData].self)
        } catch {
            return request.eventLoop.future(error: error)
        }
        return request.application.leaf.renderer.render(path: "../../Templates/\(template).json", context: context).flatMap { buffer in
            var bufferVar = buffer
            do {
                guard let multiStaticMap = try bufferVar.readJSONDecodable(MultiStaticMap.self, length: buffer.readableBytes) else {
                    throw Abort(.badRequest, reason: "Failed to decode json")
                }
                return self.handleRequest(request: request, multiStaticMap: multiStaticMap)
            } catch {
                return request.eventLoop.future(error: error)
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
                return self.generateResponse(request: request, path: path)
            }
        }
    }

    private func generateResponse(request: Request, path: String) -> EventLoopFuture<Response> {
        let response: Response
        if (try? request.query.get(Bool.self, at: "pregenerate")) ?? false {
            response = Response(body: .init(string: path.components(separatedBy: "/").last!))
            response.headers.add(name: .contentType, value: "text/plain")
        } else {
            response = request.fileio.streamFile(at: path)
            response.headers.add(name: .cacheControl, value: "max-age=604800, must-revalidate")
        }
        return request.eventLoop.future(response)
    }

}
