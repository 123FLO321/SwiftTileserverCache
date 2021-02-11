//
//  String+BashEncode.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 17.05.20.
//

import Foundation

internal extension String {
    var bashEncoded: String {
        return self
            .replacingOccurrences(of: "#", with: "\\#")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: " ", with: "\\ ")
    }
}
