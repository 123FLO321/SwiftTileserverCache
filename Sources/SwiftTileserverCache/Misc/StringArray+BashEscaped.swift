//
//  String+BashEncode.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 17.05.20.
//

import Foundation

internal extension Array where Element == String {
    var bashEscaped: [String] {
        return self.map({$0.bashEscaped})
    }
}
