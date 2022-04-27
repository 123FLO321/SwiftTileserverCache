//
// Created by Florian Kostenzer on 27.04.22.
//

import Foundation
import ShellOut

@discardableResult
public func escapedShellOut(
    to command: String,
    arguments: [String] = [],
    at path: String = ".",
    process: Process = .init(),
    outputHandle: FileHandle? = nil,
    errorHandle: FileHandle? = nil
) throws -> String {
    return try shellOut(to: command, arguments: arguments.bashEscaped, at: path, process: process, outputHandle: outputHandle, errorHandle: errorHandle)
}