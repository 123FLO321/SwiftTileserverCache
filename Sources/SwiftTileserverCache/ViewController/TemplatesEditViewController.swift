import Foundation
import Vapor
import Leaf

internal class TemplatesEditViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var templateName: String?
        var templateContent: String?
    }

    let templatesController: TemplatesController

    init(templatesController: TemplatesController) {
        self.templatesController = templatesController
    }

    internal func render(request: Request) -> EventLoopFuture<View> {
        let templateName = request.parameters.get("name")
        let pageName: String
        if let templateName = templateName {
            pageName = "Edit Template \(templateName)"
        } else {
            pageName = "New Template"
        }
        let context = Context(
            pageId: "templates",
            pageName: pageName,
            templateName: templateName,
            templateContent: (templateName != nil) ? templatesController.getTemplateContent(name: templateName!) : nil
        )
        return self.render(request: request, template: "TemplatesEdit", context: context)
    }

}
