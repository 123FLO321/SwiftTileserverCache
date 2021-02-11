//
//  String+CamelCase.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 11.02.21.
//

import Foundation

internal extension String {
    var toCamelCase: String {
        return self.components(separatedBy: ["_", "-", " ", "."])
            .map({
                $0.replacingCharacters(
                    in: ...$0.startIndex,
                    with: $0.first?.uppercased() ?? ""
                )
            }).joined()
    }
}
