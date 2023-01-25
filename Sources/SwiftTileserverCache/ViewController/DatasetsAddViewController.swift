import Foundation
import Vapor
import Leaf

internal class DatasetsAddViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
    }

    init() {}

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "datasets",
            pageName: "Add Dataset"
        )
        return self.render(request: request, template: "DatasetsAdd", context: context)
    }

}
