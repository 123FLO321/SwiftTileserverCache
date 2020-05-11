import Vapor

public func configure(_ app: Application) throws {
    try cachecleaners(app)
    try routes(app)
}
