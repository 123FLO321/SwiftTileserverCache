//
//  main.swift
//  SwiftTileserverCacheApp
//
//  Created by Florian Kostenzer on 01.11.19.
//

import SwiftTileserverCache
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
