//
//  String+BashEncode.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 17.05.20.
//

import Foundation

internal extension String {
    var bashEscaped: String {
        let safeChars = [
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            "/", "-", "+", "_", ",", ".", ":", "="
        ]

        return self.trimmingCharacters(in: .nonBaseCharacters).map { char in
            let string = String(char)
            if safeChars.contains(string) {
                return string
            } else {
                return "\\" + string
            }
        }.joined()
    }
}
