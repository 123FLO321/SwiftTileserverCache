import Foundation
import Vapor
import Leaf

internal class DatasetsViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var datasets: [String]
    }

    let datasetsController: DatasetsController

    init(datasetsController: DatasetsController) {
        self.datasetsController = datasetsController
    }

    internal func render(request: Request) throws -> EventLoopFuture<View> {
        let datasets: [String]
        do {
            datasets = try datasetsController.getDatasets()
        } catch {
            throw Abort(.internalServerError, reason: "Failed to get datasets: (\(error.localizedDescription))")
        }
        let context = Context(
            pageId: "datasets",
            pageName: "Datasets",
            datasets: datasets
        )
        return self.render(request: request, template: "Datasets", context: context)
    }

}
