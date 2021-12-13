//
//  CacheCleaner.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 02.11.19.
//

import Foundation
import Vapor
import ShellOut

public class CacheCleaner {

    private let logger: Logger
    private let folder: URL
    private let maxAgeMinutes: UInt32

    public init(folder: String, maxAgeMinutes: UInt32?, clearDelaySeconds: UInt32?) {
        self.folder = URL(fileURLWithPath: folder)
        self.maxAgeMinutes = maxAgeMinutes ?? 0
        self.logger = Logger(label: "CacheCleaner-\(folder)")
        let thread = DispatchQueue(label: "CacheCleaner-\(folder)")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        if maxAgeMinutes != nil && clearDelaySeconds != nil {
            self.logger.notice("Starting CacheCleaner for \(folder) with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
            thread.async {
                while true {
                    self.runOnce()
                    sleep(clearDelaySeconds!)
                }
            }
        }
    }
    
    private func runOnce() {
        do {
            let count = Int(try shellOut(to: "./Resources/Scripts/clear.bash", arguments: [folder.path, "\(maxAgeMinutes)"])) ?? 0
            if count != 0 {
                logger.info("Removed \(count) Files")
            }
        } catch {
            logger.warning("Failed to run remove script")
        }
    }
    
}
