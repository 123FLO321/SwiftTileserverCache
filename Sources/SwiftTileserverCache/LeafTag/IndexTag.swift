//
//  FormatTag.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 12.05.20.
//

import Vapor
import Leaf

class IndexTag: LeafTag {

    func render(_ ctx: LeafContext) throws -> LeafData {
        guard ctx.parameters.count == 2,
          let array = ctx.parameters.first?.array,
          let index = ctx.parameters.last?.int else {
            throw Abort(.badRequest, reason: "index tag rquires exactly 2 Argument: (array: [LeafData], index: int)")
        }
        return array[index]
    }

}
