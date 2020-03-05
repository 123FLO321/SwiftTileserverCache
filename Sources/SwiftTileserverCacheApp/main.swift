
//
//  main.swift
//  SwiftTileserverCacheApp
//
//  Created by Florian Kostenzer on 01.11.19.
//

import Foundation
import LoggerAPI
import HeliumLogger
import Backtrace
import FileKit
import SwiftTileserverCache

let level: LoggerMessageType
if ProcessInfo.processInfo.environment["LOGGING_LEVEL"]?.lowercased() == "debug" {
    level = .debug
} else if ProcessInfo.processInfo.environment["LOGGING_LEVEL"]?.lowercased() == "verbose" {
    level = .verbose
} else {
    level = .info
}

let logger = HeliumLogger(.debug)
logger.format = "[(%date)] [(%type)] [(%file)] (%msg)"
Log.logger = logger

Backtrace.install()

guard let tileServerURL = ProcessInfo.processInfo.environment["TILE_SERVER_URL"] else {
    print("TILE_SERVER_URL enviroment not set. Exiting...")
    exit(78)
}

let cacheDir = FileKit.projectFolderURL.appendingPathComponent("Cache", isDirectory: true)
let tileCacheDir = cacheDir.appendingPathComponent("Tile", isDirectory: true)
let staticCacheDir = cacheDir.appendingPathComponent("Static", isDirectory: true)
let staticWithMarkersCacheDir = cacheDir.appendingPathComponent("StaticWithMarkers", isDirectory: true)
let staticMultiCacheDir = cacheDir.appendingPathComponent("StaticMulti", isDirectory: true)
let markerCacheDir = cacheDir.appendingPathComponent("Marker", isDirectory: true)

Log.info("Creating missing Directories")
try? FileManager().createDirectory(at: cacheDir, withIntermediateDirectories: false, attributes: nil)
try? FileManager().createDirectory(at: tileCacheDir, withIntermediateDirectories: false, attributes: nil)
try? FileManager().createDirectory(at: staticCacheDir, withIntermediateDirectories: false, attributes: nil)
try? FileManager().createDirectory(at: staticWithMarkersCacheDir, withIntermediateDirectories: false, attributes: nil)
try? FileManager().createDirectory(at: staticMultiCacheDir, withIntermediateDirectories: false, attributes: nil)
try? FileManager().createDirectory(at: markerCacheDir, withIntermediateDirectories: false, attributes: nil)

let webserver = WebServer(tileServerURL: tileServerURL)

if let maxAgeMinutes = UInt32(ProcessInfo.processInfo.environment["TILE_CACHE_MAX_AGE_MINUTES"] ?? "") {
    let clearDelaySeconds = UInt32(ProcessInfo.processInfo.environment["TILE_CACHE_DELAY_SECONDS"] ?? "") ?? 900
    Log.info("Starting CacheCleaner for Tiles with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
    _ = CacheCleaner(folder: tileCacheDir, maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
}

if let maxAgeMinutes = UInt32(ProcessInfo.processInfo.environment["STATIC_CACHE_MAX_AGE_MINUTES"] ?? "") {
    let clearDelaySeconds = UInt32(ProcessInfo.processInfo.environment["STATIC_CACHE_DELAY_SECONDS"] ?? "") ?? 900
    Log.info("Starting CacheCleaner for Static with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
    _ = CacheCleaner(folder: staticCacheDir, maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
}

if let maxAgeMinutes = UInt32(ProcessInfo.processInfo.environment["STATIC_MARKER_CACHE_MAX_AGE_MINUTES"] ?? "") {
    let clearDelaySeconds = UInt32(ProcessInfo.processInfo.environment["STATIC_MARKER_CACHE_DELAY_SECONDS"] ?? "") ?? 900
    Log.info("Starting CacheCleaner for StaticWithMarkers with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
    _ = CacheCleaner(folder: staticWithMarkersCacheDir, maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
}

if let maxAgeMinutes = UInt32(ProcessInfo.processInfo.environment["STATIC_MUTLI_CACHE_MAX_AGE_MINUTES"] ?? "") {
    let clearDelaySeconds = UInt32(ProcessInfo.processInfo.environment["STATIC_MULTI_CACHE_DELAY_SECONDS"] ?? "") ?? 900
    Log.info("Starting CacheCleaner for StaticMulti with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
    _ = CacheCleaner(folder: staticMultiCacheDir, maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
}

if let maxAgeMinutes = UInt32(ProcessInfo.processInfo.environment["MARKER_CACHE_MAX_AGE_MINUTES"] ?? "") {
    let clearDelaySeconds = UInt32(ProcessInfo.processInfo.environment["MARKER_CACHE_DELAY_SECONDS"] ?? "") ?? 900
    Log.info("Starting CacheCleaner for Markers with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
    _ = CacheCleaner(folder: markerCacheDir, maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
}

while true {
    sleep(UInt32.max)
}
