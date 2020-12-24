import Foundation
import Vapor
import Leaf

internal class StylesAddLocalViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
    }

    init() {}

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "styles",
            pageName: "Add Local Style"
        )
        return self.render(request: request, template: "StylesAddLocal", context: context)
    }

}
