import Foundation
import Vapor
import Leaf

internal class FontsAddViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
    }

    init() {}

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "fonts",
            pageName: "Add Fonts"
        )
        return self.render(request: request, template: "FontsAdd", context: context)
    }

}
