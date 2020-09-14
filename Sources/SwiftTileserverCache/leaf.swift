import Vapor

public func leaf(_ app: Application) throws {
    app.views.use(.leaf)
    if app.environment.isRelease {
        app.leaf.cache.isEnabled = true
        let clearDelaySeconds = UInt32(Environment.get("TEMPLATES_CACHE_DELAY_SECONDS") ?? "") ?? 60
        app.logger.notice("Starting LeafCacheCleaner for Templates with clearDelaySeconds: \(clearDelaySeconds)")
        _ = LeafCacheCleaner(app: app, folder: "Templates", clearDelaySeconds: clearDelaySeconds)
    } else {
        app.leaf.cache.isEnabled = false
    }
    app.leaf.configuration.rootDirectory = ""
    app.leaf.tags["index"] = IndexTag()
    app.leaf.tags["format"] = FormatTag()
    app.leaf.tags["pad"] = PadTag()
    app.leaf.tags["round"] = RoundTag()
}
