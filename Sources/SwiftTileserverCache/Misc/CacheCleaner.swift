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
    private let fileManager = FileManager()
    
    public init(folder: String, maxAgeMinutes: UInt32, clearDelaySeconds: UInt32=60) {
        self.folder = URL(fileURLWithPath: folder)
        self.maxAgeMinutes = maxAgeMinutes
        self.logger = Logger(label: "CacheCleaner-\(folder)")
        let thread = DispatchQueue(label: "CacheCleaner-\(folder)")
        thread.async {
            while true {
                do {
                    try self.runOnce()
                } catch {
                    self.logger.error("Failed to run CacheCleaner")
                }
                sleep(clearDelaySeconds)
            }
        }
    }
    
    private func runOnce() throws {
        let now = Date()
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
        for file in files {
            do {
                if let date = try file.resourceValues(forKeys: [.attributeModificationDateKey]).contentModificationDate,
                    now.timeIntervalSince(date) >= Double(maxAgeMinutes * 60) {
                    logger.debug("Removing file \(file.lastPathComponent) (Too old)")
                    do {
                        try fileManager.removeItem(at: file)
                    } catch {
                        logger.warning("Failed to delete \(file.lastPathComponent): \(error)")
                    }
                }
            } catch {
                logger.warning("Failed to read contentModificationDate of \(file.lastPathComponent): \(error)")
            }
        }
    }
    
}
