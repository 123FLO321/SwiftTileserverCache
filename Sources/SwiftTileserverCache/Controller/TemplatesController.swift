import Vapor
import Leaf

internal class TemplatesController {

    struct PreviewTemplate: Decodable {
        enum Mode: String, Decodable {
            case staticMap = "StaticMap"
            case multiStaticMap = "MultiStaticMap"
        }
        var template: String
        var context: [String: LeafData]
        var mode: Mode
    }

    struct SaveTemplate: Codable {
        var template: String
        var name: String
        var oldName: String
    }

    private let folder: String
    private let staticMapController: StaticMapController
    private let multiStaticMapController: MultiStaticMapController

    internal init(folder: String, staticMapController: StaticMapController, multiStaticMapController: MultiStaticMapController) {
        self.folder = folder
        self.staticMapController = staticMapController
        self.multiStaticMapController = multiStaticMapController
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    }


    // MARK: - Routes

    internal func preview(request: Request) throws -> EventLoopFuture<Response> {
        let template = try request.content.decode(PreviewTemplate.self)

        let tempFilename = "\(folder)/preview-\(UUID().uuidString).json"
        return request.fileio.writeFile(ByteBuffer(string: template.template), at: tempFilename).flatMap {
            return request.leaf.render(path: tempFilename, context: template.context).flatMap({ buffer in
                var bufferVar = buffer
                do {
                    if template.mode == .staticMap, let staticMap = try bufferVar.readJSONDecodable(StaticMap.self, length: buffer.readableBytes) {
                        return self.staticMapController.handleRequest(request: request, staticMap: staticMap)
                    } else if template.mode == .multiStaticMap, let multiStaticMap = try bufferVar.readJSONDecodable(MultiStaticMap.self, length: buffer.readableBytes) {
                        return self.multiStaticMapController.handleRequest(request: request, multiStaticMap: multiStaticMap)
                    } else {
                        return request.eventLoop.future(error: Abort(.badRequest, reason: "Invalid Template"))
                    }
                } catch let error as DecodingError {
                    return request.eventLoop.future(error: Abort(.badRequest, reason: error.description))
                } catch {
                    return request.eventLoop.future(error: Abort(.badRequest, reason: error.localizedDescription))
                }
            }).always { _ in 
                try? FileManager.default.removeItem(atPath: tempFilename)
            }
        }
    }

    internal func save(request: Request) throws -> EventLoopFuture<Response> {
        let template = try request.content.decode(SaveTemplate.self)
        let fileName = "\(folder)/\(template.name).json"
        try? FileManager.default.removeItem(atPath: fileName)
        if template.name != template.oldName {
            try? FileManager.default.removeItem(atPath: "\(self.folder)/\(template.oldName).json")
        }
        return request.fileio.writeFile(ByteBuffer(string: template.template), at: fileName).map { _ in

            return Response(status: .ok)
        }
    }

    internal func delete(request: Request) throws -> Response {
        try FileManager.default.removeItem(atPath: "\(folder)/\(request.parameters.get("name") ?? "").json")
        return Response(status: .ok)
    }

    // MARK: - Utils

    func getTemplates() throws -> [String] {
        return try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "json" })
            .map({ $0.deletingPathExtension().lastPathComponent })
    }

    func getTemplateContent(name: String) -> String? {
        let data = FileManager.default.contents(atPath: folder + "/" + name + ".json")
        return (data != nil) ? String(data: data!, encoding: .utf8) : nil
    }

}

