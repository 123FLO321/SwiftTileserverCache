import Vapor
import Leaf

func routes(_ app: Application) throws {
    guard let tileServerURL = Environment.get("TILE_SERVER_URL") else {
        app.logger.critical("TILE_SERVER_URL enviroment not set. Exiting...")
        throw Abort(.badRequest, reason: "TILE_SERVER_URL enviroment not set")
    }

    let statsController = StatsController(tileServerURL: tileServerURL, fileToucher: FileToucher())
    app.get(use: statsController.get)
    app.get("styles", use: statsController.getStyles)

    let tileController = TileController(tileServerURL: tileServerURL, statsController: statsController)
    app.get("tile", ":style", ":z", ":x", ":y", ":scale", ":format", use: tileController.get)

    let staticMapController = StaticMapController(tileServerURL: tileServerURL, statsController: statsController)
    app.get("staticmap", use: staticMapController.get)
    app.get("staticmap", ":template", use: staticMapController.getTemplate)
    app.post("staticmap", ":template", use: staticMapController.postTemplate)
    app.get("staticmap", "pregenerated", ":id", use: staticMapController.getPregenerated)
    app.post("staticmap", use: staticMapController.post)

    let multiStaticMapController = MultiStaticMapController(tileServerURL: tileServerURL, statsController: statsController, staticMapController: staticMapController)
    app.get("multistaticmap", use: multiStaticMapController.get)
    app.get("multistaticmap", ":template", use: multiStaticMapController.getTemplate)
    app.post("multistaticmap", ":template", use: multiStaticMapController.postTemplate)
    app.get("multistaticmap", "pregenerated", ":id", use: multiStaticMapController.getPregenerated)
    app.post("multistaticmap", use: multiStaticMapController.post)
}
