//
//  StaticMapController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor

internal struct TileController {

    internal let tileServerURL: String
    internal let statsController: StatsController

    // MARK: - Routes

    internal func get(request: Request) throws -> EventLoopFuture<Response> {
        guard
            let style = request.parameters.get("style"),
            let z = request.parameters.get("z", as: Int.self),
            let x = request.parameters.get("x", as: Int.self),
            let y = request.parameters.get("y", as: Int.self),
            let scale = request.parameters.get("scale", as: UInt8.self),
            scale >= 1,
            let format = request.parameters.get("format"),
            format == "png" || format == "jpg" else {
                throw Abort(.badRequest)
        }

        let path = "Cache/Tile/\(style)-\(z)-\(x)-\(y)-\(scale).\(format)"
        if !FileManager.default.fileExists(atPath: path) {
            return generateTileAndResponse(request: request, path: path, style: style, z: z, x: x, y: y, scale: scale, format: format).always {_ in
                request.application.logger.info("Served a generated tile")
                self.statsController.tileServed(new: true, path: path, style: style)
            }
        } else {
            return generateResponse(request: request, path: path).always {_ in
                request.application.logger.info("Served a cached tile")
                self.statsController.tileServed(new: false, path: path, style: style)
            }
        }
    }

    // MARK: - Utils

    private func generateTileAndResponse(request: Request, path: String, style: String, z: Int, x: Int, y: Int, scale: UInt8, format: String) -> EventLoopFuture<Response> {
        let scaleString = scale == 1 ? "" : "@\(scale)x"
        let tileURL = "\(tileServerURL)/styles/\(style)/\(z)/\(x)/\(y)\(scaleString).\(format)"
        return APIUtils.downloadFile(request: request, from: tileURL, to: path).flatMap {
            return self.generateResponse(request: request, path: path)
        }

    }

    private func generateResponse(request: Request, path: String) -> EventLoopFuture<Response> {
        let response = request.fileio.streamFile(at: path)
        response.headers.add(name: .cacheControl, value: "max-age=604800, must-revalidate")
        return request.eventLoop.future(response)
    }

}
