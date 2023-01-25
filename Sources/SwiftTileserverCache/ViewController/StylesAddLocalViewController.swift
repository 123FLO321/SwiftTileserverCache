import Foundation
import Vapor
import Leaf

internal class StylesAddLocalViewController: ViewController {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var previewLatitude: Double
        var previewLongitude: Double
    }

    let previewLatitude: Double
    let previewLongitude: Double

    init() {
        self.previewLatitude = Double(Environment.get("PREVIEW_LATIDUDE") ?? "") ?? 47.377105
        self.previewLongitude = Double(Environment.get("PREVIEW_LONGITUDE") ?? "") ?? 8.541655
    }

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "styles",
            pageName: "Add Local Style",
            previewLatitude: self.previewLatitude,
            previewLongitude: self.previewLongitude
        )
        return self.render(request: request, template: "StylesAddLocal", context: context)
    }

}
