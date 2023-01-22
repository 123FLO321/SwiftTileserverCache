import Vapor

public func tileserver(_ app: Application) throws {
    if !FileManager.default.fileExists(atPath: "TileServer/config.json") &&
           (Environment.get("ADMIN_USERNAME")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") != "" &&
           (Environment.get("ADMIN_PASSWORD")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") != "" {
        app.logger.info("Copying default TileServer configuration")
        try FileManager.default.copyItem(atPath: "Resources/TileServer/config.json", toPath: "TileServer/config.json")
        try FileManager.default.copyItem(atPath: "Resources/TileServer/Empty.mbtiles", toPath: "TileServer/Datasets/Combined.mbtiles")
    }
}
