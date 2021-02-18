import Foundation
import Vapor
import Leaf

internal class StatsViewController: ViewController {

    internal struct Context: ViewControllerContext {
        struct Ratio: Encodable {
            var key: String
            var value: String
        }
        var pageId: String
        var pageName: String
        var tileHitRatios: [Ratio]
        var staticMapHitRatios: [Ratio]
        var markerHitRatios: [Ratio]
    }

    let statsController: StatsController

    init(statsController: StatsController) {
        self.statsController = statsController
    }

    internal func render(request: Request) -> EventLoopFuture<View> {
        let tileHitRatios = statsController.getTileStats().map { (ratio) -> Context.Ratio in
            return .init(key: ratio.key, value: ratio.value.displayValue)
        }
        let staticMapHitRatios = statsController.getStaticMapStats().map { (ratio) -> Context.Ratio in
            return .init(key: ratio.key, value: ratio.value.displayValue)
        }
        let markerHitRatios = statsController.getMarkerStats().map { (ratio) -> Context.Ratio in
            return .init(key: ratio.key, value: ratio.value.displayValue)
        }
        let context = Context(
            pageId: "stats",
            pageName: "Stats",
            tileHitRatios: tileHitRatios,
            staticMapHitRatios: staticMapHitRatios,
            markerHitRatios: markerHitRatios
        )
        return self.render(request: request, template: "Stats", context: context)
    }

}
