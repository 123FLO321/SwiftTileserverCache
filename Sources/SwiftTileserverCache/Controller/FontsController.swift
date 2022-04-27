//
//  DatasetsController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 15.09.20.
//

import Vapor

internal class FontsController {

    struct SaveFont: Content {
        var file: File
    }

    #if os(macOS)
    private static let buildGlyphsCommand = "/usr/local/opt/node/bin/node /usr/local/bin/build-glyphs"
    #else
    private static let buildGlyphsCommand = "/usr/local/bin/build-glyphs"
    #endif

    private let folder: String
    private let tempFolder: String

    internal init(folder: String, tempFolder: String) {
        self.folder = folder
        self.tempFolder = tempFolder
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: tempFolder)
        try? FileManager.default.createDirectory(atPath: tempFolder, withIntermediateDirectories: true)
    }

    // MARK: - Routes

    internal func add(request: Request) throws -> EventLoopFuture<Response> {
        let font = try request.content.decode(SaveFont.self)
        let tempFile = "\(tempFolder)/\(UUID().uuidString).\(font.file.extension ?? "tff")"
        let name = font.file.filename.split(separator: ".").dropLast().joined(separator: ".").toCamelCase
        return request.fileio.writeFile(font.file.data, at: tempFile).flatMap { _ in
            return self.buildGlyphs(request: request, file: tempFile, name: name).map { _ in
                return Response(status: .ok)
            }
        }
    }

    internal func delete(request: Request) throws -> Response {
        try FileManager.default.removeItem(atPath: "\(folder)/\(request.parameters.get("name") ?? "")")
        return Response(status: .ok)
    }

    // MARK: - Utils

    internal func getFonts() throws -> [String] {
        return try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)
            .filter({ $0.hasDirectoryPath })
            .map({ $0.deletingPathExtension().lastPathComponent })
    }

    private func buildGlyphs(request: Request, file: String, name: String) -> EventLoopFuture<Void> {
        let path = "\(folder)/\(name)"
        return request.application.threadPool.runIfActive(eventLoop: request.eventLoop) {
            try? FileManager.default.removeItem(atPath: path)
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
                try escapedShellOut(to: FontsController.buildGlyphsCommand, arguments: [file, path])
            } catch {
                try? FileManager.default.removeItem(atPath: path)
                throw Abort(.internalServerError, reason: "Failed to create glyphs: \(error.localizedDescription)")
            }
        }
    }

}
