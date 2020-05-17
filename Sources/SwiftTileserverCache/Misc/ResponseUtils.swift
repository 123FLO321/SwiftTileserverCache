//
//  ResponseUtils.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 17.05.20.
//

import Vapor

internal class ResponseUtils<T> where T: Codable {

    internal static func generateResponse(request: Request, staticMap: T?, path: String) -> EventLoopFuture<Response> {
        let response: Response
        let regeneratableFuture: EventLoopFuture<Void>?
        if (try? request.query.get(Bool.self, at: "pregenerate")) ?? false {
            if let staticMap = staticMap, (try? request.query.get(Bool.self, at: "regeneratable")) ?? false {
                let path = "Cache/Regeneratable/\(path.components(separatedBy: "/").last!).json"
                if !FileManager.default.fileExists(atPath: path) {
                    regeneratableFuture = storeRegeneratable(request: request, staticMap: staticMap, path: path)
                } else {
                    regeneratableFuture = nil
                }
            } else {
                regeneratableFuture = nil
            }
            response = Response(body: .init(string: path.components(separatedBy: "/").last!))
            response.headers.add(name: .contentType, value: "text/plain")
        } else {
            regeneratableFuture = nil
            response = request.fileio.streamFile(at: path)
            response.headers.add(name: .cacheControl, value: "max-age=604800, must-revalidate")
        }
        if let regeneratableFuture = regeneratableFuture {
            return regeneratableFuture.flatMap {
                return request.eventLoop.future(response)
            }
        }
        return request.eventLoop.future(response)
    }

    internal static func storeRegeneratable(request: Request, staticMap: T, path: String) -> EventLoopFuture<Void> {
        return request.application.fileio.openFile(
                path: path,
                mode: .write,
                flags: .allowFileCreation(),
                eventLoop: request.eventLoop
        ).flatMap { fileHandle in
            guard let buffer = try? JSONEncoder().encodeAsByteBuffer(staticMap, allocator: .init()) else {
                return request.eventLoop.future(error: Abort(.internalServerError, reason: "Failed to store regeneratable StaticMap"))
            }
            return request.application.fileio.write(
                fileHandle: fileHandle,
                buffer: buffer,
                eventLoop: request.eventLoop
            ).always { _ in
                try? fileHandle.close()
            }
        }
    }

    internal static func readRegeneratable(request: Request, path: String, as: T.Type) -> EventLoopFuture<T> {
        return request.application.fileio.openFile(
                path: path,
                mode: .read,
                eventLoop: request.eventLoop
        ).flatMap { fileHandle in
            return request.application.fileio.read(fileHandle: fileHandle, byteCount: 131_072, allocator: .init(), eventLoop: request.eventLoop).flatMapThrowing { buffer in
                return try JSONDecoder().decode(T.self, from: buffer)
            }.always { _ in
                try? fileHandle.close()
            }
        }
    }

}
