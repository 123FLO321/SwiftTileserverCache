import Foundation
import Vapor
import Leaf

internal class DatasetsDeleteViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var datasetName: String
    }

    init() {}

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "datasets",
            pageName: "Delete Datase",
            datasetName: request.parameters.get("name") ?? ""
        )
        return self.render(request: request, template: "DatasetsDelete", context: context)
    }

}
