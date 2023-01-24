import Vapor
import Leaf
import ZIPFoundation

internal class StylesController {

    struct SaveStyleFiles: Content {
        var id: String
        var name: String
        var styleJson: File
        var spriteJson: File
        var spriteImage: File
        var spriteJson2x: File
        var spriteImage2x: File
    }

    struct SaveStyleZip: Content {
        var id: String
        var name: String
        var zip: File
    }

    private let tileServerURL: String
    private var externalStyles: [String: Style]
    private let folder: String
    private let fontsController: FontsController

    internal init(tileServerURL: String, externalStyles: [Style], folder: String, fontsController: FontsController) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: "\(folder)/External", withIntermediateDirectories: false)
        self.tileServerURL = tileServerURL
        self.externalStyles = (externalStyles + StylesController.loadExternalStyles(folder: folder)).reduce(into: [String: Style](), { (into, style) in
            into[style.id] = style
        })
        self.folder = folder
        self.fontsController = fontsController
    }

    // MARK: - Routes

    internal func get(request: Request) -> EventLoopFuture<[Style]> {
        return loadLocalStyles(request: request).map { styles in
            let externalStyles = Array(self.externalStyles.values) as [Style]
            return (styles + externalStyles).map { $0.removingURL }
        }
    }
    
    internal func getWithAnalysis(request: Request) -> EventLoopFuture<[Style]> {
        return get(request: request).flatMap({ styles in
            let analysisFutures = styles.filter({$0.external != true}).map({ style in
                return self.analyse(request: request, id: style.id).map({ analysis in
                    return (id: style.id, analysis: analysis)
                })
            })
            return analysisFutures.flatten(on: request.eventLoop).map { analysis in
                return styles.map({ style in
                    var newStyle = style
                    newStyle.analysis = analysis.first(where: {$0.id == style.id})?.analysis
                    return newStyle
                })
            }
        })
    }

    internal func analyse(request: Request, id: String) -> EventLoopFuture<Style.Analysis> {
        return analyseUsage(request: request, id: id).flatMap({ usage in
            return self.analyseAvailableIcons(request: request, id: id).flatMapThrowing({ icons in
                let fonts = try self.fontsController.getFonts()
                let missingIcons = usage.icons.filter({!icons.contains($0)})
                let missingFonts = usage.fonts.filter({!fonts.contains($0)})
                return .init(
                    missingFonts: missingFonts,
                    missingIcons: missingIcons
                )
            })
        }).recover({ _ in
            return .init(
                missingFonts: ["error loading style"],
                missingIcons: ["error loading style"]
            )
        })
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

    internal func addLocal(request: Request) async throws -> HTTPStatus {
        var name: String
        var id: String
        var styleJsonData: Data
        var spriteJsonData: Data
        var spriteImageData: Data
        var spriteJson2xData: Data
        var spriteImage2xData: Data
        if var style = try? request.content.decode(SaveStyleZip.self) {
            name = style.name
            id = style.id
            (styleJsonData, spriteJsonData, spriteImageData, spriteJson2xData, spriteImage2xData) = try await extractDataFromZip(request: request, style: &style)
        } else if var style = try? request.content.decode(SaveStyleFiles.self) {
            name = style.name
            id = style.id
            (styleJsonData, spriteJsonData, spriteImageData, spriteJson2xData, spriteImage2xData) = try extractDataFromFiles(style: &style)
        } else {
            throw Abort(.badRequest, reason: "Invalid request")
        }

        guard var styleJson = try? JSONSerialization.jsonObject(with: styleJsonData) as? [String: Any] else {
            throw Abort(.badRequest, reason: "style.json is not valid json")
        }
        styleJson["name"] = name
        styleJson["sprite"] = "{styleJsonFolder}/\(id)/sprite"
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
            if var layout = newLayer["layout"] as? [String: Any], let textFonts = layout["text-font"] as? [String] {
                layout["text-font"] = textFonts.map({$0.toCamelCase})
                newLayer["layout"] = layout
            }

            return newLayer
        }
        styleJson["layers"] = layers

        guard let modifiedStyleData = try? JSONSerialization.data(withJSONObject: styleJson, options: .prettyPrinted) else {
            throw Abort(.internalServerError, reason: "failed to modify style.json")
        }

        let stylePath = "\(folder)/\(id).json"
        let spritePath = "\(folder)/\(id)"
        try? FileManager.default.removeItem(atPath: stylePath)
        try? FileManager.default.removeItem(atPath: spritePath)
        try FileManager.default.createDirectory(atPath: spritePath, withIntermediateDirectories: false)
        try await request.fileio.writeFile(ByteBuffer(data: modifiedStyleData), at: stylePath).get()
        try await request.fileio.writeFile(ByteBuffer(data: spriteJsonData), at: "\(spritePath)/sprite.json").get()
        try await request.fileio.writeFile(ByteBuffer(data: spriteImageData), at: "\(spritePath)/sprite.png").get()
        try await request.fileio.writeFile(ByteBuffer(data: spriteJson2xData), at: "\(spritePath)/sprite@2x.json").get()
        try await request.fileio.writeFile(ByteBuffer(data: spriteImage2xData), at: "\(spritePath)/sprite@2x.png").get()
        return .ok
    }


    internal func extractFile(request: Request, archive: Archive, fileName: String) async throws -> Data {
        guard let entry = archive[fileName] else {
            throw Abort(.badRequest, reason: "\(fileName) is required")
        }
        let promise = request.eventLoop.makePromise(of: Data.self)
        var data = Data()
        _ = try archive.extract(entry, consumer: { bytes in
            data.append(bytes)
            if data.count >= entry.uncompressedSize {
                promise.succeed(data)
            }
        })
        return try await promise.futureResult.get()
    }

    internal func extractDataFromZip(request: Request, style: inout SaveStyleZip) async throws -> (styleJson: Data, spriteJson: Data, spriteImage: Data, spriteJson2x: Data, spriteImage2x: Data) {
        guard let zipData = style.zip.data.readData(length: style.zip.data.readableBytes), let archive = Archive(data: zipData, accessMode: .read) else {
            throw Abort(.badRequest, reason: "zip is invalid")
        }
        let styleJsonData = try await extractFile(request: request, archive: archive, fileName: "style.json")
        let spriteJsonData = try await extractFile(request: request, archive: archive, fileName: "sprite.json")
        let spriteImageData = try await extractFile(request: request, archive: archive, fileName: "sprite.png")
        let spriteJson2xData = try await extractFile(request: request, archive: archive, fileName: "sprite@2x.json")
        let spriteImage2xData = try await extractFile(request: request, archive: archive, fileName: "sprite@2x.png")
        return (styleJsonData, spriteJsonData, spriteImageData, spriteJson2xData, spriteImage2xData)
    }

    internal func extractDataFromFiles(style: inout SaveStyleFiles) throws -> (styleJson: Data, spriteJson: Data, spriteImage: Data, spriteJson2x: Data, spriteImage2x: Data) {
        guard let styleJsonData = style.styleJson.data.readData(length: style.styleJson.data.readableBytes) else {
            throw Abort(.badRequest, reason: "style.json is required")
        }
        guard let spriteJsonData = style.spriteJson.data.readData(length: style.spriteJson.data.readableBytes) else {
            throw Abort(.badRequest, reason: "sprite.json is required")
        }
        guard let spriteImageData = style.spriteImage.data.readData(length: style.spriteImage.data.readableBytes) else {
            throw Abort(.badRequest, reason: "sprite.png is required")
        }
        guard let spriteJson2xData = style.spriteJson2x.data.readData(length: style.spriteJson2x.data.readableBytes) else {
            throw Abort(.badRequest, reason: "sprite@2x.json is required")
        }
        guard let spriteImage2xData = style.spriteImage2x.data.readData(length: style.spriteImage2x.data.readableBytes) else {
            throw Abort(.badRequest, reason: "sprite@2x.png is required")
        }
        return (styleJsonData, spriteJsonData, spriteImageData, spriteJson2xData, spriteImage2xData)
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
    
    private func analyseUsage(request: Request, id: String) -> EventLoopFuture<(fonts: [String], icons: [String])> {
        return request.application.fileio.openFile(
            path: "\(folder)/\(id).json",
            mode: .read,
            eventLoop: request.eventLoop
        ).flatMap { fileHandle in
            return request.application.fileio.read(fileHandle: fileHandle, byteCount: 131_072, allocator: .init(), eventLoop: request.eventLoop).flatMapThrowing { buffer in
                guard let styleJson = try? JSONSerialization.jsonObject(with: Data(buffer: buffer)) as? [String: Any],
                      let layers = styleJson["layers"] as? [[String: Any]]
                else {
                    throw Abort(.badRequest, reason: "style.json is not valid josn")
                }
                var fonts = Set<String>()
                var icons = Set<String>()
                
                // TODO: Implement Resolved Icons
                for layer in layers {
                    if let layout = layer["layout"] as? [String: Any] {
                        if let textFonts = layout["text-font"] as? [String], !textFonts.isEmpty {
                            fonts.insert(textFonts[0])
                        }
                        if let iconImage = layout["icon-image"] as? String, !iconImage.isEmpty {
                            icons.insert(iconImage)
                        }
                    }
                    if let paint = layer["paint"] as? [String: Any] {
                        if let backgroundPattern = paint["background-pattern"] as? String, !backgroundPattern.isEmpty {
                            icons.insert(backgroundPattern)
                        }
                        if let fillPattern = paint["fill-pattern"] as? String, !fillPattern.isEmpty {
                            icons.insert(fillPattern)
                        }
                        if let linePattern = paint["line-pattern"] as? String, !linePattern.isEmpty {
                            icons.insert(linePattern)
                        }
                        if let fillExtrusionPattern = paint["fill-extrusion-pattern"] as? String, !fillExtrusionPattern.isEmpty {
                            icons.insert(fillExtrusionPattern)
                        }
                    }
                    
                }
                return (fonts: Array(fonts), icons: Array(icons))
            }.always { _ in
                try? fileHandle.close()
            }
        }
    }
    
    private func analyseAvailableIcons(request: Request, id: String) -> EventLoopFuture<[String]> {
        return request.application.fileio.openFile(
            path: "\(folder)/\(id)/sprite.json",
            mode: .read,
            eventLoop: request.eventLoop
        ).flatMap { fileHandle in
            return request.application.fileio.read(fileHandle: fileHandle, byteCount: 131_072, allocator: .init(), eventLoop: request.eventLoop).flatMapThrowing { buffer in
                guard let iconsJson = try? JSONSerialization.jsonObject(with: Data(buffer: buffer)) as? [String: Any] else {
                    throw Abort(.badRequest, reason: "sprite.json is not valid josn")
                }
                return Array(iconsJson.keys)
            }.always { _ in
                try? fileHandle.close()
            }
        }
    }


}
