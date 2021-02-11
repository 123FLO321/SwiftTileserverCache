//
//  String+IsEmpty.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 11.02.21.
//

import Foundation

internal extension String {
    var isEmpty: Bool {
        return self.trimmingCharacters(in: .whitespaces) == ""
    }
}
