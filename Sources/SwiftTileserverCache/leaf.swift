import Vapor

public func leaf(_ app: Application) throws {
    app.views.use(.leaf)
    app.leaf.cache.isEnabled = false
    app.leaf.tags["index"] = IndexTag()
    app.leaf.tags["format"] = FormatTag()
    app.leaf.tags["pad"] = PadTag()
    app.leaf.tags["round"] = RoundTag()
}
