import Vapor
import Leaf

internal class StatsController {

    private let fileToucher: FileToucher

    private let tileHitRatioLock = NSLock()
    private var tileHitRatios = [String: HitRatio]()
    private let staticMapHitRatioLock = NSLock()
    private var staticMapHitRatios = [String: HitRatio]()
    private let markerHitRatioLock = NSLock()
    private var markerHitRatios = [String: HitRatio]()

    internal init(fileToucher: FileToucher) {
        self.fileToucher = fileToucher
    }

    // MARK: - Stats

    internal func tileServed(new: Bool, path: String, style: String) {
        if !new { fileToucher.touch(fileName: path) }
        tileHitRatioLock.lock()
        if tileHitRatios[style] == nil { tileHitRatios[style] = HitRatio() }
        tileHitRatios[style]!.served(new: new)
        tileHitRatioLock.unlock()
    }

    internal func staticMapServed(new: Bool, path: String, style: String) {
        if !new { fileToucher.touch(fileName: path) }
        staticMapHitRatioLock.lock()
        if staticMapHitRatios[style] == nil { staticMapHitRatios[style] = HitRatio() }
        staticMapHitRatios[style]!.served(new: new)
        staticMapHitRatioLock.unlock()
    }

    internal func markerServed(new: Bool, path: String, domain: String) {
        if !new { fileToucher.touch(fileName: path) }
        markerHitRatioLock.lock()
        if markerHitRatios[domain] == nil { markerHitRatios[domain] = HitRatio() }
        markerHitRatios[domain]!.served(new: new)
        markerHitRatioLock.unlock()
    }

    internal func getTileStats() -> [String : HitRatio] {
        self.tileHitRatioLock.lock()
        let tileHitRatios = self.tileHitRatios
        self.tileHitRatioLock.unlock()
        return tileHitRatios
    }

    internal func getStaticMapStats() -> [String : HitRatio] {
        self.staticMapHitRatioLock.lock()
        let staticMapHitRatios = self.staticMapHitRatios
        self.staticMapHitRatioLock.unlock()
        return staticMapHitRatios
    }

    internal func getMarkerStats() -> [String : HitRatio] {
        self.markerHitRatioLock.lock()
        let markerHitRatios = self.markerHitRatios
        self.markerHitRatioLock.unlock()
        return markerHitRatios
    }

}
