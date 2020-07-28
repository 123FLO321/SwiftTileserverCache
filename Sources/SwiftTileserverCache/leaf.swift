import Vapor

public func leaf(_ app: Application) throws {
    app.views.use(.leaf)
    app.leaf.cache.isEnabled = app.environment.isRelease
    app.leaf.configuration.rootDirectory = ""
    app.leaf.tags["index"] = IndexTag()
    app.leaf.tags["format"] = FormatTag()
    app.leaf.tags["pad"] = PadTag()
    app.leaf.tags["round"] = RoundTag()
}
