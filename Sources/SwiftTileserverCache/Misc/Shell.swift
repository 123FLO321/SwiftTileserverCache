//
//  Shell.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 29.10.18.
//

import Foundation

internal class Shell {
    
    private var args: [String]
    
    internal init (_ args: String...) {
        self.args = args
    }

    internal init (_ args: [String]) {
        self.args = args
    }
    
    internal func run(errorPipe: Any?=nil, inputPipe: Any?=nil) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        if errorPipe != nil {
            task.standardError = errorPipe
        }
        if inputPipe != nil {
            task.standardInput = inputPipe
        }
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
    internal func runError(standartPipe: Any?=nil, inputPipe: Any?=nil) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        if standartPipe != nil {
            task.standardOutput = standartPipe
        }
        if inputPipe != nil {
            task.standardInput = inputPipe
        }
        task.standardError = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
}
