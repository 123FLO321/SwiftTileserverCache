import Foundation
import Vapor
import Leaf

internal class StylesDeleteLocalViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var styleId: String
    }

    init() {}

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "styles",
            pageName: "Delete Local Style",
            styleId: request.parameters.get("id") ?? ""
        )
        return self.render(request: request, template: "StylesDeleteLocal", context: context)
    }

}
