//
//  StaticMapController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor

internal class TileController {

    private let tileServerURL: String
    private let statsController: StatsController
    private let stylesController: StylesController

    internal init(tileServerURL: String, statsController: StatsController, stylesController: StylesController) {
        self.tileServerURL = tileServerURL
        self.statsController = statsController
        self.stylesController = stylesController
    }

    // MARK: - Routes

    internal func get(request: Request) throws -> EventLoopFuture<Response> {
        guard
            let style = request.parameters.get("style"),
            let z = request.parameters.get("z", as: Int.self),
            let x = request.parameters.get("x", as: Int.self),
            let y = request.parameters.get("y", as: Int.self),
            let scale = request.parameters.get("scale", as: UInt8.self),
            scale >= 1,
            let formatString = request.parameters.get("format"),
            let format = ImageFormat(rawValue: formatString) else {
                throw Abort(.badRequest)
        }
        return generateTileAndResponse(request: request, style: style, z: z, x: x, y: y, scale: scale, format: format)
    }

    // MARK: - Utils

    internal func generateTile(request: Request, style: String, z: Int, x: Int, y: Int, scale: UInt8, format: ImageFormat) -> EventLoopFuture<String> {
        let path = "Cache/Tile/\(style)-\(z)-\(x)-\(y)-\(scale).\(format)"
        guard !FileManager.default.fileExists(atPath: path) else {
            request.application.logger.info("Served a cached tile")
            self.statsController.tileServed(new: false, path: path, style: style)
            return request.eventLoop.future(path)
        }

        let scaleString = scale == 1 ? "" : "@\(scale)x"
        let tileURL: String
        if let url = stylesController.getExternalStyle(name: style)?.url {
            tileURL = url.replacingOccurrences(of: "{z}", with: "\(z)")
                         .replacingOccurrences(of: "{x}", with: "\(x)")
                         .replacingOccurrences(of: "{y}", with: "\(y)")
                         .replacingOccurrences(of: "{scale}", with: "\(scale)")
                         .replacingOccurrences(of: "{@scale}", with: scaleString)
                         .replacingOccurrences(of: "{format}", with: format.rawValue)
        } else {
            tileURL = "\(tileServerURL)/styles/\(style)/\(z)/\(x)/\(y)\(scaleString).\(format)"
        }
        return APIUtils.downloadFile(request: request, from: tileURL, to: path, type: "image").flatMapError { error in
            return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load tile: \(tileURL) (\(error.localizedDescription))"))
        }.always { result in
            if case .success = result {
                request.application.logger.info("Served a generated tile")
                self.statsController.tileServed(new: true, path: path, style: style)
            }
        }.transform(to: path)
    }

    private func generateTileAndResponse(request: Request, style: String, z: Int, x: Int, y: Int, scale: UInt8, format: ImageFormat) -> EventLoopFuture<Response> {
        return generateTile(request: request, style: style, z: z, x: x, y: y, scale: scale, format: format).flatMap { path in
            return self.generateResponse(request: request, path: path)
        }
    }

    private func generateResponse(request: Request, path: String) -> EventLoopFuture<Response> {
        let response = request.fileio.streamFile(at: path)
        response.headers.add(name: .cacheControl, value: "max-age=604800, must-revalidate")
        return request.eventLoop.future(response)
    }

}
