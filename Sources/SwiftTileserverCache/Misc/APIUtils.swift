import Foundation
import Vapor

public class APIUtils {
    
    private init() {}
    
    public static func downloadFile(request: Request, from: String, to: String, type: String?) -> EventLoopFuture<Void> {
        let headers = HTTPHeaders([("User-Agent", "TileserverCache")])
        return request.client.get(URI(string: from), headers: headers).flatMap { response in
            let errorReason: String
            if response.status.code >= 200 && response.status.code < 300 {
                if let type = type, response.content.contentType?.type != type {
                    errorReason = "Failed to load file. Got invalid type: \(request.content.contentType?.description ?? "none")"
                } else if let body = response.body, body.readableBytes != 0 {
                    return request.application.fileio.openFile(
                        path: to,
                        mode: .write,
                        flags: .allowFileCreation(),
                        eventLoop: request.eventLoop
                    ).flatMap { fileHandle in
                        request.application.fileio.write(
                            fileHandle: fileHandle,
                            buffer: body,
                            eventLoop: request.eventLoop
                        ).always { _ in
                            try? fileHandle.close()
                        }
                    }
                } else {
                    errorReason = "Failed to load file. Got empty data"
                }
            } else {
                errorReason = "Failed to load file. Got \(response.status.code)"
            }
            request.application.logger.error(.init(stringLiteral: errorReason))
            return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
        }
    }
    
    public static func loadJSON<T: Decodable>(request: Request, from: String) -> EventLoopFuture<T> {
        let headers = HTTPHeaders([("User-Agent", "TileserverCache")])
        return request.client.get(URI(string: from), headers: headers).flatMap { response in
            let errorReason: String
            if response.status.code >= 200 && response.status.code < 300 {
                do {
                    let json = try response.content.decode(T.self)
                    return request.eventLoop.future(json)
                } catch {
                    errorReason = "Failed to parse JSON"
                }
            } else {
                errorReason = "Failed to load file. Got \(response.status.code)"
            }
            request.application.logger.error(.init(stringLiteral: errorReason))
            return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
        }
    }
}
