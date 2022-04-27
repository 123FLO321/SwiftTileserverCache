//
//  DatasetsController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 15.09.20.
//

import Vapor

internal class DatasetsController {

    private static let tileJoinCommand = "/usr/local/bin/tile-join"

    private let folder: String
    private let listFolder: String

    internal init(folder: String) {
        self.folder = folder
        self.listFolder = folder + "/List"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: listFolder, withIntermediateDirectories: true)
    }

    // MARK: - Routes

    internal func download(request: Request, websocket: WebSocket) -> () {
        websocket.onText { (websocket, text) in
            let split = text.components(separatedBy: ";")
            guard split.count == 2, let url = URL(string: split[1]) else {
                return websocket.send("Invalid URL")
            }
            let name = split[0]
            request.logger.info("Downloading \(name).mbtiles (\(url.absoluteString))")
            APIUtils.downloadFile(request: request, from: url.absoluteString, to: self.listFolder + "/\(name).mbtiles", type: nil).whenComplete { (result) in
                switch result {
                case .success:
                    request.logger.info("Downloading \(name).mbtiles done")
                    websocket.send("downloaded")
                    request.logger.info("Combining mbtiles")
                    self.combineTiles(request: request, websocket: websocket).whenComplete { (result) in
                        switch result {
                        case .success:
                            request.logger.info("Combining mbtiles done")
                            websocket.send("ok")
                        case .failure(let error):
                            request.logger.error("Combining mbtiles failed: \(error.localizedDescription)")
                            websocket.send(error.localizedDescription)
                        }
                    }
                case .failure(let error):
                    request.logger.error("Downloading \(name).mbtiles failed: \(error.localizedDescription)")
                    websocket.send(error.localizedDescription)
                }
            }
        }
    }

    internal func delete(request: Request, websocket: WebSocket) -> () {
        websocket.onText { (websocket, text) in
            let name = text
            do {
                try FileManager.default.removeItem(atPath: self.listFolder + "/\(name).mbtiles")
            } catch {
                request.logger.error("Failed to delete \(name).mbtiles: \(error.localizedDescription)")
                websocket.send(error.localizedDescription)
                return
            }
            websocket.send("deleted")
            request.logger.info("Combining mbtiles")
            self.combineTiles(request: request, websocket: websocket).whenComplete { (result) in
                switch result {
                case .success:
                    request.logger.info("Combining mbtiles done")
                    websocket.send("ok")
                case .failure(let error):
                    request.logger.error("Combining mbtiles failed: \(error.localizedDescription)")
                    websocket.send("Combining mbtiles failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Utils

    internal func getDatasets() throws -> [String] {
        return try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: listFolder), includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "mbtiles" })
            .map({ $0.deletingPathExtension().lastPathComponent })
    }

    private func combineTiles(request: Request, websocket: WebSocket) -> EventLoopFuture<Void> {
        let datasets: [String]
        do {
            datasets = try getDatasets()
        } catch {
            return request.eventLoop.makeFailedFuture("Failed to get mbtiles: \(error.localizedDescription)")
        }
        if datasets.count == 1 {
            try? FileManager.default.removeItem(atPath: self.folder + "/Combined.mbtiles")
            do {
                try escapedShellOut(to: "/bin/ln", arguments: ["-s", "List/\(datasets[0]).mbtiles", "Combined.mbtiles"], at: self.folder)
            } catch {
                return request.eventLoop.makeFailedFuture("Failed to link mbtiles: \(error.localizedDescription)")
            }
            return request.eventLoop.future()
        } else {
            return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
                do {
                    try escapedShellOut(to: DatasetsController.tileJoinCommand, arguments: ["--force", "-o", "Combined.mbtiles", "List/*.mbtiles"], at: self.folder)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to get mbtiles: \(error.localizedDescription)")
                }
            }
        }
    }

}
