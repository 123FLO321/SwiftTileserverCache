import Vapor

public func configure(_ app: Application) throws {
    try cachecleaners(app)
    try leaf(app)
    try routes(app)
    try tileserver(app)
}
