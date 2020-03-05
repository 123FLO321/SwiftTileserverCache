//
//  PersistentHashable.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 04.03.20.
//

import Foundation
import Cryptor

public protocol PersistentHashable {
    var uniqueHash: String { get }
}

extension PersistentHashable where Self: Codable {
    public var uniqueHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let json = try! encoder.encode(self)
        return Data(Digest(using: .md5).update(data: json)!.final()).base64EncodedString().replacingOccurrences(of: "/", with: "_")
    }
}
