//
//  StylesController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 15.09.20.
//

import Vapor
import Leaf

internal class StylesController {

    struct SaveStyle: Content {
        var id: String
        var name: String
        var styleJson: File
        var spriteJson: File
        var spriteImage: File
        var spriteJson2x: File
        var spriteImage2x: File
    }

    private let tileServerURL: String
    private var externalStyles: [String: Style]
    private let folder: String

    internal init(tileServerURL: String, externalStyles: [Style], folder: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: "\(folder)/External", withIntermediateDirectories: false)
        self.tileServerURL = tileServerURL
        self.externalStyles = (externalStyles + StylesController.loadExternalStyles(folder: folder)).reduce(into: [String: Style](), { (into, style) in
            into[style.id] = style
        })
        self.folder = folder
    }

    // MARK: - Routes

    internal func get(request: Request) -> EventLoopFuture<[Style]> {
        return loadLocalStyles(request: request).map { styles in
            let externalStyles = Array(self.externalStyles.values) as [Style]
            return (styles + externalStyles).map { $0.removingURL }
        }
    }

    internal func addExternal(request: Request) throws -> EventLoopFuture<HTTPStatus> {
        let style = try request.content.decode(Style.self)
        guard style.external == true, style.url != nil else {
            throw Abort(.badRequest, reason: "URL is required for external styles")
        }
        self.externalStyles[style.id] = style
        return saveExternalStyles(request: request).map({.ok})
    }

    internal func deleteExternal(request: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = request.parameters.get("id") else {
            throw Abort(.badRequest, reason: "ID parameter is required")
        }
        self.externalStyles[id] = nil
        return saveExternalStyles(request: request).map({.ok})
    }

    internal func addLocal(request: Request) throws -> EventLoopFuture<HTTPStatus> {
        var style = try request.content.decode(SaveStyle.self)
        guard let styleData = style.styleJson.data.readData(length: style.styleJson.data.readableBytes) else {
            throw Abort(.badRequest, reason: "style.json is not readable")
        }
        guard var styleJson = try? JSONSerialization.jsonObject(with: styleData) as? [String: Any] else {
            throw Abort(.badRequest, reason: "style.json is not valid josn")
        }
        styleJson["name"] = style.name
        styleJson["sprite"] = "{styleJsonFolder}/\(style.id)/sprite"
        styleJson["glyphs"] = "{fontstack}/{range}.pbf"
        styleJson["sources"] = [
            "combined": [
                "type": "vector",
                "url": "mbtiles://{combined}"
            ]
        ]
        let layers = (styleJson["layers"] as? [[String: Any]] ?? []).map { (layer) -> [String: Any] in
            var newLayer = layer
            if newLayer["source"] as? String != nil {
                newLayer["source"] = "combined"
            }
            return newLayer
        }
        styleJson["layers"] = layers

        guard let modifiedStyleData = try? JSONSerialization.data(withJSONObject: styleJson, options: .prettyPrinted) else {
            throw Abort(.internalServerError, reason: "failed to modify style.json")
        }

        let stylePath = "\(folder)/\(style.id).json"
        let spritePath = "\(folder)/\(style.id)"
        try? FileManager.default.removeItem(atPath: stylePath)
        try? FileManager.default.removeItem(atPath: spritePath)
        try FileManager.default.createDirectory(atPath: spritePath, withIntermediateDirectories: false)
        var fileWrites: [EventLoopFuture<Void>] = []
        fileWrites.append(request.fileio.writeFile(ByteBuffer(data: modifiedStyleData), at: stylePath))
        fileWrites.append(request.fileio.writeFile(style.spriteJson.data, at: "\(spritePath)/sprite.json"))
        fileWrites.append(request.fileio.writeFile(style.spriteImage.data, at: "\(spritePath)/sprite.png"))
        fileWrites.append(request.fileio.writeFile(style.spriteJson2x.data, at: "\(spritePath)/sprite@2x.json"))
        fileWrites.append(request.fileio.writeFile(style.spriteImage2x.data, at: "\(spritePath)/sprite@2x.png"))
        return fileWrites.flatten(on: request.eventLoop).map({.ok})
    }

    internal func deleteLocal(request: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = request.parameters.get("id") else {
            throw Abort(.badRequest, reason: "ID parameter is required")
        }
        let stylePath = "\(folder)/\(id).json"
        let spritePath = "\(folder)/\(id)"
        try? FileManager.default.removeItem(atPath: stylePath)
        try? FileManager.default.removeItem(atPath: spritePath)
        return request.eventLoop.future(.ok)
    }

    // MARK: - Utils

    internal func getExternalStyle(name: String) -> Style? {
        return externalStyles[name]
    }

    private func loadLocalStyles(request: Request) -> EventLoopFuture<[Style]> {
        let stylesURL = "\(tileServerURL)/styles.json"
        return APIUtils.loadJSON(request: request, from: stylesURL).flatMapError { error in
            return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load styles: (\(error.localizedDescription))"))
        }
    }

    private static func loadExternalStyles(folder: String) -> [Style] {
        let stylesFile = "\(folder)/External/styles.json"
        guard let data = FileManager.default.contents(atPath: stylesFile) else {
            return []
        }
        do {
            return try JSONDecoder().decode([Style].self, from: data)
        } catch {
            return []
        }
    }

    private func saveExternalStyles(request: Request) -> EventLoopFuture<Void> {
        let stylesFile = "\(folder)/External/styles.json"
        try? FileManager.default.removeItem(atPath: stylesFile)
        let byteBuffer: ByteBuffer
        do {
            byteBuffer = try JSONEncoder().encodeAsByteBuffer(Array(self.externalStyles.values) as [Style], allocator: .init())
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
        return request.fileio.writeFile(byteBuffer, at: stylesFile)
    }


}
