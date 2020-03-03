//
//  CacheCleaner.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 02.11.19.
//

import Foundation
import LoggerAPI

public class CacheCleaner {
    
    private let folder: URL
    private let maxAgeMinutes: UInt32
    private let fileManager = FileManager()
    
    public init(folder: URL, maxAgeMinutes: UInt32, clearDelaySeconds: UInt32=60) {
        self.folder = folder
        self.maxAgeMinutes = maxAgeMinutes
        let thread = DispatchQueue(label: "CacheCleaner-\(folder.absoluteString)")
        thread.async {
            while true {
                do {
                    try self.runOnce()
                } catch {
                    Log.error("Failed to run CacheCleaner")
                }
                sleep(clearDelaySeconds)
            }
        }
    }
    
    private func runOnce() throws {
        let now = Date()
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentAccessDateKey])
        for file in files {
            do {
                if let date = try file.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate,
                   now.timeIntervalSince(date) >= Double(maxAgeMinutes * 60) {
                    Log.info("Removing file \(file.lastPathComponent) (Too old)")
                    do {
                        try fileManager.removeItem(at: file)
                    } catch {
                        Log.warning("Failed to delete \(file.lastPathComponent): \(error)")
                    }
                }
            } catch {
                Log.warning("Failed to read contentAccessDateKey of \(file.lastPathComponent): \(error)")
            }
        }
    }
    
}
