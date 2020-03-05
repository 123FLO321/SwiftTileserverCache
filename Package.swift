// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "SwiftTileserverCache",
    products: [
        .executable(
            name: "SwiftTileserverCacheApp",
            targets: [
                "SwiftTileserverCacheApp"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura", .upToNextMinor(from: "2.7.0")),
        .package(url: "https://github.com/IBM-Swift/FileKit.git", from: "0.0.2"),
        .package(url: "https://github.com/IBM-Swift/LoggerAPI", .upToNextMinor(from: "1.9.0")),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger", .upToNextMinor(from: "1.8.1")),
        .package(url: "https://github.com/IBM-Swift/BlueCryptor", .upToNextMinor(from: "1.0.0")),
        .package(url: "https://github.com/ianpartridge/swift-backtrace", .upToNextMinor(from: "1.1.1")),
        .package(url: "https://github.com/stencilproject/Stencil", .upToNextMinor(from: "0.13.0")),
    ],
    targets: [
        .target(
            name: "SwiftTileserverCache",
            dependencies: [
                "Kitura",
                "FileKit",
                "LoggerAPI",
                "Cryptor",
                "Stencil"
            ]
        ),
        .target(
            name: "SwiftTileserverCacheApp",
            dependencies: [
                "SwiftTileserverCache",
                "HeliumLogger",
		"Backtrace"
            ]
        ),
        .testTarget(
            name: "SwiftTileserverCacheTests",
            dependencies: [
                "SwiftTileserverCache"
            ]
        ),
    ]
)
