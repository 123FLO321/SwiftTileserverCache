import Foundation
import Vapor
import Leaf

internal protocol ViewControllerContext: Encodable {
    var pageId: String { get }
    var pageName: String { get }
}

internal protocol ViewController {
    func render(request: Request) throws -> EventLoopFuture<View>
}

internal extension ViewController {
    func render<E>(request: Request, template: String, context: E) -> EventLoopFuture<View> where E: ViewControllerContext {
        return request.view.render("Resources/Views/\(template)", context)
    }
}
