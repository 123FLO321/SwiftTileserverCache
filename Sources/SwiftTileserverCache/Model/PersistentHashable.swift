//
//  PersistentHashable.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 04.03.20.
//

import Foundation
import Vapor

public protocol PersistentHashable {
    var persistentHash: String { get }
}

extension PersistentHashable where Self: Codable {
    public var persistentHash: String {
        let encoder = JSONEncoder.custom(format: .sortedKeys)
        let data = try! encoder.encode(self)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString().replacingOccurrences(of: "/", with: "_")
    }
}

extension String: PersistentHashable {
    public var persistentHash: String {
        let data = self.data(using: .utf8)!
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString().replacingOccurrences(of: "/", with: "_")
    }
}
