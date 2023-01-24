import Vapor
import Leaf

func routes(_ app: Application) throws {
    guard let tileServerURL = Environment.get("TILE_SERVER_URL") else {
        app.logger.critical("TILE_SERVER_URL enviroment not set. Exiting...")
        throw Abort(.badRequest, reason: "TILE_SERVER_URL enviroment not set")
    }
    let externalStyles = ProcessInfo.processInfo.environment.filter({ element in
        return element.key.starts(with: "TILE_URL_")
    }).compactMap({ element -> Style in
        let key = element.key.replacingOccurrences(of: "TILE_URL_", with: "").replacingOccurrences(of: " ", with: "").lowercased()
        return Style(
            id: key.replacingOccurrences(of: "_", with: "-"),
            name: key.replacingOccurrences(of: "_", with: " ").capitalized,
            external: true,
            url: element.value
        )
    })

    if let maxBodySize = Environment.get("MAX_BODY_SIZE") {
        app.routes.defaultMaxBodySize = ByteCount(stringLiteral: maxBodySize)
    }

    let statsController = StatsController(fileToucher: FileToucher())

    let fontsController = FontsController(folder: "TileServer/Fonts", tempFolder: "Temp")
    let stylesController = StylesController(tileServerURL: tileServerURL, externalStyles: externalStyles, folder: "TileServer/Styles", fontsController: fontsController)
    app.get("styles", use: stylesController.get)

    let tileController = TileController(tileServerURL: tileServerURL, statsController: statsController, stylesController: stylesController)
    app.get("tile", ":style", ":z", ":x", ":y", ":scale", ":format", use: tileController.get)

    let staticMapController = StaticMapController(tileServerURL: tileServerURL, tileController: tileController, statsController: statsController, stylesController: stylesController)
    app.get("staticmap", use: staticMapController.get)
    app.get("staticmap", ":template", use: staticMapController.getTemplate)
    app.post("staticmap", ":template", use: staticMapController.postTemplate)
    app.get("staticmap", "pregenerated", ":id", use: staticMapController.getPregenerated)
    app.post("staticmap", use: staticMapController.post)

    let multiStaticMapController = MultiStaticMapController(staticMapController: staticMapController, statsController: statsController)
    app.get("multistaticmap", use: multiStaticMapController.get)
    app.get("multistaticmap", ":template", use: multiStaticMapController.getTemplate)
    app.post("multistaticmap", ":template", use: multiStaticMapController.postTemplate)
    app.get("multistaticmap", "pregenerated", ":id", use: multiStaticMapController.getPregenerated)
    app.post("multistaticmap", use: multiStaticMapController.post)


    let protected = app.grouped("admin").grouped(app.sessions.middleware, AdminAuthenticator())

    // Admin API

    let datasetController = DatasetsController(folder: "TileServer/Datasets")
    protected.webSocket("api", "datasets", "add", onUpgrade: datasetController.download)
    protected.webSocket("api", "datasets", "delete", onUpgrade: datasetController.delete)
    protected.on(.POST, "api", "datasets", "add", body: .collect(maxSize: "128gb"), use: datasetController.add)

    protected.on(.POST, "api", "fonts", "add", body: .collect(maxSize: "64mb"), use: fontsController.add)
    protected.delete("api", "fonts", "delete", ":name", use: fontsController.delete)

    protected.post("api", "styles", "external", "add", use: stylesController.addExternal)
    protected.delete("api", "styles", "external", ":id", use: stylesController.deleteExternal)

    protected.on(.POST, "api", "styles", "local", "add", body: .collect(maxSize: "64mb"), use: stylesController.addLocal)
    protected.delete("api", "styles", "local", ":id", use: stylesController.deleteLocal)

    let templatesController = TemplatesController(folder: "Templates", staticMapController: staticMapController, multiStaticMapController: multiStaticMapController)
    protected.post("api", "templates", "preview", use: templatesController.preview)
    protected.post("api", "templates", "save", use: templatesController.save)
    protected.delete("api", "templates", "delete", ":name", use: templatesController.delete)

    // Admin Views

    protected.get("stats", use: StatsViewController(statsController: statsController).render)

    protected.get("datasets", use: DatasetsViewController(datasetsController: datasetController).render)
    protected.get("datasets", "add", use: DatasetsAddViewController().render)
    protected.get("datasets", "delete", ":name", use: DatasetsDeleteViewController().render)

    protected.get("fonts", use: FontsViewController(fontsController: fontsController).render)
    protected.get("fonts", "add", use: FontsAddViewController().render)

    protected.get("styles", use: StylesViewController(stylesController: stylesController).render)
    protected.get("styles", "external", "add", use: StylesAddExternalViewController().render)
    protected.get("styles", "local", "add", use: StylesAddLocalViewController().render)
    protected.get("styles", "local", "delete", ":id", use: StylesDeleteLocalViewController().render)

    protected.get("templates", use: TemplatesViewController(templatesController: templatesController).render)
    protected.get("templates", "add", use: TemplatesEditViewController(templatesController: templatesController).render)
    protected.get("templates", "edit", ":name", use: TemplatesEditViewController(templatesController: templatesController).render)

    app.get("admin") { (request) -> Response in
        return request.redirect(to: "/admin/stats")
    }

    app.get { (request) -> Response in
        return request.redirect(to: "/admin/stats")
    }

}
