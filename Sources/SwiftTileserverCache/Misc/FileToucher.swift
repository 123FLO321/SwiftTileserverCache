//
//  FileToucher.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 06.05.20.
//

import Foundation
import Vapor
import ShellOut

public class FileToucher {

    private let logger: Logger
    private let fileManager = FileManager()
    private let queueLock = NSLock()
    private var queue = [String]()

    public init() {
        let uuidString = UUID().uuidString
        self.logger = Logger(label: "FileToucher-\(uuidString)")
        let thread = DispatchQueue(label: "FileToucher-\(uuidString)")
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
            for slice in queue.chunked(into: 100) {
                do {
                    try shellOut(to: "/usr/bin/touch -c", arguments: slice)
                    logger.info("Touched \(queue.count) Files")
                } catch {
                    logger.warning("Failed to touch files: \(error)")
                }
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

