import Foundation
import Vapor
import Leaf

internal class FontsViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var fonts: [String]
    }

    let fontsController: FontsController

    init(fontsController: FontsController) {
        self.fontsController = fontsController
    }

    internal func render(request: Request) throws -> EventLoopFuture<View> {
        let fonts: [String]
        do {
            fonts = try fontsController.getFonts()
        } catch {
            throw Abort(.internalServerError, reason: "Failed to get fonts: (\(error.localizedDescription))")
        }
        let context = Context(
            pageId: "fonts",
            pageName: "Fonts",
            fonts: fonts
        )
        return self.render(request: request, template: "Fonts", context: context)
    }

}
