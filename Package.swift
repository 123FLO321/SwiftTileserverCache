// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftTileserverCache",
    platforms: [
        .macOS(.v12) // linux does not yet have runtime availability checks so this doesn't apply to linux yet
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMinor(from: "4.69.1")),
        .package(url: "https://github.com/vapor/leaf", .upToNextMinor(from: "4.2.4")),
        .package(url: "https://github.com/JohnSundell/ShellOut", .upToNextMinor(from: "2.3.0")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.16"))
    ],
    targets: [
        .target(
            name: "SwiftTileserverCache",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "ShellOut", package: "ShellOut"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .executableTarget(
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
