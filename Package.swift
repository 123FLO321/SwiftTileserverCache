// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftTileserverCache",
    platforms: [
        .macOS(.v10_15) // linux does not yet have runntime availability checks so this doesn't apply to linux yet
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf", from: "4.0.0-rc"),
        .package(url: "https://github.com/JohnSundell/ShellOut", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "SwiftTileserverCache",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "ShellOut", package: "ShellOut")
            ]
        ),
        .target(
            name: "SwiftTileserverCacheApp",
            dependencies: [
                .target(name: "SwiftTileserverCache"),
            ]
        ),
        .testTarget(
            name: "SwiftTileserverCacheTests",
            dependencies: [
                .target(name: "SwiftTileserverCache"),
            ]
        )
    ]
)
