//
//  Style.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 03.03.20.
//

import Vapor

public struct Style: Content {
    
    public struct Analysis: Codable {
        var missingFonts: [String]
        var missingIcons: [String]
    }
    
    public var id: String
    public var name: String
    public var external: Bool?
    public var url: String?
    public var analysis: Analysis?

    public var removingURL: Style {
        return Style(id: id, name: name, external: external, url: nil)
    }
}
