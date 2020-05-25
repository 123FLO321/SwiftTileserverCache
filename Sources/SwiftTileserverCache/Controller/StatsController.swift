//
//  StatsController.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 08.05.20.
//

import Vapor
import Leaf

internal class StatsController {

    private let tileServerURL: String
    private let fileToucher: FileToucher

    private let tileHitRatioLock = NSLock()
    private var tileHitRatios = [String: HitRatio]()
    private let staticMapHitRatioLock = NSLock()
    private var staticMapHitRatios = [String: HitRatio]()
    private let markerHitRatioLock = NSLock()
    private var markerHitRatios = [String: HitRatio]()

    internal init(tileServerURL: String, fileToucher: FileToucher) {
        self.tileServerURL = tileServerURL
        self.fileToucher = fileToucher
    }

    // MARK: - Routes

    internal func get(request: Request) -> EventLoopFuture<View> {

        self.tileHitRatioLock.lock()
        let tileHitRatios = self.tileHitRatios.map { (ratio) -> [String: String] in
            return ["key": "\(ratio.key)", "value": "\(ratio.value.displayValue)"]
        }
        self.tileHitRatioLock.unlock()
        self.staticMapHitRatioLock.lock()
        let staticMapHitRatios = self.staticMapHitRatios.map { (ratio) -> [String: String] in
            return ["key": "\(ratio.key)", "value": "\(ratio.value.displayValue)"]
        }
        self.staticMapHitRatioLock.unlock()
        self.markerHitRatioLock.lock()
        let markerHitRatios = self.markerHitRatios.map { (ratio) -> [String: String] in
            return ["key": "\(ratio.key)", "value": "\(ratio.value.displayValue)"]
        }
        self.markerHitRatioLock.unlock()

        let context = [
            "tileHitRatios": tileHitRatios,
            "staticMapHitRatios": staticMapHitRatios,
            "markerHitRatios": markerHitRatios
        ]
        return request.view.render("Stats", context)
    }

    internal func getStyles(request: Request) -> EventLoopFuture<[Style]> {
        return loadStyles(request: request)
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

    // MARK: - Utils

    private func loadStyles(request: Request) -> EventLoopFuture<[Style]> {
        let stylesURL = "\(tileServerURL)/styles.json"
        return APIUtils.loadJSON(request: request, from: stylesURL).flatMapError { error in
            return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to load styles: (\(error.localizedDescription))"))
        }
    }

}
