//
//  FormatTag.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 12.05.20.
//

import Vapor
import Leaf

class FormatTag: LeafTag {

    func render(_ ctx: LeafContext) throws -> LeafData {
        guard ctx.parameters.count == 2,
          let anyArgument = ctx.parameters.first,
          let format = ctx.parameters.last?.string,
          let argument: CVarArg = (anyArgument.int ?? anyArgument.double) else {
            throw Abort(.badRequest, reason: "format tag rquires exactly 2 Argument: (argument: Int|Double, format: String)")
        }
        return LeafData.string(String(format: format, argument))
    }

}
