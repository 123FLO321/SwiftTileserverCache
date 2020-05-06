//
//  FileToucher.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 06.05.20.
//

import Foundation
import LoggerAPI
import ShellOut

public class FileToucher {

    private let fileManager = FileManager()
    private let queueLock = NSLock()
    private var queue = [String]()

    public init() {
        let thread = DispatchQueue(label: "FileToucher-\(UUID().uuidString)")
        thread.async {
            while true {
                self.runOnce()
                sleep(30)
            }
        }
    }

    private func runOnce() {
        queueLock.lock()
        if !queue.isEmpty {
            do {
                try shellOut(to: "/usr/bin/touch", arguments: queue)
            } catch {
                Log.warning("Failed to touch files: \(error)")
            }
            queue = []
        }
        queueLock.unlock()
    }

    public func touch(fileName: String) {
        queueLock.lock()
        queue.append(fileName)
        queueLock.unlock()
    }

}

