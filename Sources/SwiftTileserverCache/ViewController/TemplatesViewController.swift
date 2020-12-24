import Foundation
import Vapor
import Leaf

internal class TemplatesViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var templates: [String]
    }

    let templatesController: TemplatesController

    init(templatesController: TemplatesController) {
        self.templatesController = templatesController
    }

    internal func render(request: Request) throws -> EventLoopFuture<View> {
        let templates: [String]
        do {
           templates = try templatesController.getTemplates()
        } catch {
           throw Abort(.internalServerError, reason: "Failed to get datasets: (\(error.localizedDescription))")
        }
        let context = Context(
           pageId: "templates",
           pageName: "Templates",
           templates: templates
        )
        return self.render(request: request, template: "Templates", context: context)
    }

}
