//
//  PadTag.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 12.05.20.
//

import Vapor
import Leaf

class PadTag: LeafTag {

    func render(_ ctx: LeafContext) throws -> LeafData {
        guard ctx.parameters.count == 2,
          let number = ctx.parameters.first?.int,
          let count = ctx.parameters.last?.int else {
            throw Abort(.badRequest, reason: "pad tag rquires exactly 2 Argument: (number: Int, zeros: Int)")
        }
        return LeafData.string(String(format: "%0\(count)d", number))
    }

}
