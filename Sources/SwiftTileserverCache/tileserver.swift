import Vapor

public func tileserver(_ app: Application) throws {
    if !FileManager.default.fileExists(atPath: "TileServer/config.json") {
        app.logger.info("Copying default TileServer config.json")
        try FileManager.default.copyItem(atPath: "Resources/TileServer/config.json", toPath: "TileServer/config.json")
    }
}
