//
//  CacheCleaner.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 02.11.19.
//

import Foundation
import Vapor

public class CacheCleaner {

    private let logger: Logger
    private let folder: URL
    private let maxAgeMinutes: UInt32

    public init(folder: String, maxAgeMinutes: UInt32, clearDelaySeconds: UInt32=60) {
        self.folder = URL(fileURLWithPath: folder)
        self.maxAgeMinutes = maxAgeMinutes
        self.logger = Logger(label: "CacheCleaner-\(folder)")
        let thread = DispatchQueue(label: "CacheCleaner-\(folder)")
        thread.async {
            while true {
                self.runOnce()
                sleep(clearDelaySeconds)
            }
        }
    }
    
    private func runOnce() {
        do {
            let count = Int(try escapedShellOut(to: "./Resources/Scripts/clear.bash")) ?? 0
            if count != 0 {
                logger.info("Removed \(count) Files")
            }
        } catch {
            logger.warning("Failed to run remove script")
        }
    }
    
}
