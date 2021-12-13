import Vapor

func cachecleaners(_ app: Application) throws {

    _ = CacheCleaner(
        folder: "Cache/Tile",
        maxAgeMinutes: UInt32(Environment.get("TILE_CACHE_MAX_AGE_MINUTES") ?? ""),
        clearDelaySeconds: UInt32(Environment.get("TILE_CACHE_DELAY_SECONDS") ?? "") ?? 900
    )

    _ = CacheCleaner(
        folder: "Cache/Tile",
        maxAgeMinutes: UInt32(Environment.get("STATIC_CACHE_MAX_AGE_MINUTES") ?? ""),
        clearDelaySeconds: UInt32(Environment.get("STATIC_CACHE_DELAY_SECONDS") ?? "") ?? 900
    )

    _ = CacheCleaner(
        folder: "Cache/Tile",
        maxAgeMinutes: UInt32(Environment.get("STATIC_MUTLI_CACHE_MAX_AGE_MINUTES") ?? ""),
        clearDelaySeconds: UInt32(Environment.get("STATIC_MULTI_CACHE_DELAY_SECONDS") ?? "") ?? 900
    )

    _ = CacheCleaner(
        folder: "Cache/Tile",
        maxAgeMinutes: UInt32(Environment.get("MARKER_CACHE_MAX_AGE_MINUTES") ?? ""),
        clearDelaySeconds: UInt32(Environment.get("MARKER_CACHE_DELAY_SECONDS") ?? "") ?? 900
    )

    _ = CacheCleaner(
        folder: "Cache/Regeneratable",
        maxAgeMinutes: UInt32(Environment.get("REGENERATABLE_CACHE_MAX_AGE_MINUTES") ?? ""),
        clearDelaySeconds: UInt32(Environment.get("REGENERATABLE_CACHE_DELAY_SECONDS") ?? "") ?? 900
    )

}
