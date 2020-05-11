import Vapor

func cachecleaners(_ app: Application) throws {
    app.logger.info("Creating missing Directories")
    try? FileManager().createDirectory(atPath: "Cache", withIntermediateDirectories: false)
    try? FileManager().createDirectory(atPath: "Cache/Tile", withIntermediateDirectories: false)
    try? FileManager().createDirectory(atPath: "Cache/Static", withIntermediateDirectories: false)
    try? FileManager().createDirectory(atPath: "Cache/StaticMulti", withIntermediateDirectories: false)
    try? FileManager().createDirectory(atPath: "Cache/Marker", withIntermediateDirectories: false)


    if let maxAgeMinutes = UInt32(Environment.get("TILE_CACHE_MAX_AGE_MINUTES") ?? "") {
        let clearDelaySeconds = UInt32(Environment.get("TILE_CACHE_DELAY_SECONDS") ?? "") ?? 900
        app.logger.notice("Starting CacheCleaner for Tiles with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
        _ = CacheCleaner(folder: "Cache/Tile", maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
    }

    if let maxAgeMinutes = UInt32(Environment.get("STATIC_CACHE_MAX_AGE_MINUTES") ?? "") {
        let clearDelaySeconds = UInt32(Environment.get("STATIC_CACHE_DELAY_SECONDS") ?? "") ?? 900
        app.logger.notice("Starting CacheCleaner for Tiles with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
        _ = CacheCleaner(folder: "Cache/Static", maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
    }

    if let maxAgeMinutes = UInt32(Environment.get("STATIC_MUTLI_CACHE_MAX_AGE_MINUTES") ?? "") {
        let clearDelaySeconds = UInt32(Environment.get("STATIC_MULTI_CACHE_DELAY_SECONDS") ?? "") ?? 900
        app.logger.notice("Starting CacheCleaner for Tiles with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
        _ = CacheCleaner(folder: "Cache/StaticMulti", maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
    }

    if let maxAgeMinutes = UInt32(Environment.get("MARKER_CACHE_MAX_AGE_MINUTES") ?? "") {
        let clearDelaySeconds = UInt32(Environment.get("MARKER_CACHE_DELAY_SECONDS") ?? "") ?? 900
        app.logger.notice("Starting CacheCleaner for Tiles with maxAgeMinutes: \(maxAgeMinutes) and clearDelaySeconds: \(clearDelaySeconds)")
        _ = CacheCleaner(folder: "Cache/Marker", maxAgeMinutes: maxAgeMinutes, clearDelaySeconds: clearDelaySeconds)
    }
}
