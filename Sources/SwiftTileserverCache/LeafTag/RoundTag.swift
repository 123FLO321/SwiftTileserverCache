//
//  RoundTag.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 12.05.20.
//

import Vapor
import Leaf

class RoundTag: LeafTag {

    func render(_ ctx: LeafContext) throws -> LeafData {
        guard ctx.parameters.count == 2,
          let number = ctx.parameters.first?.double,
          let count = ctx.parameters.last?.int else {
            throw Abort(.badRequest, reason: "round tag rquires exactly 2 Argument: (number: Double, decimals: Int)")
        }
        return LeafData.string(String(format: "%.\(count)f", number))
    }

}
