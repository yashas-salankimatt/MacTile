// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacTile",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacTile", targets: ["MacTile"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "MacTile",
            dependencies: ["HotKey", "MacTileCore"],
            path: "Sources/MacTile",
            resources: [
                .copy("../../sketchybar/plugins"),
                .copy("../../sketchybar/sketchybarrc")
            ]
        ),
        .target(
            name: "MacTileCore",
            dependencies: [],
            path: "Sources/MacTileCore"
        ),
        .testTarget(
            name: "MacTileTests",
            dependencies: ["MacTileCore"],
            path: "Tests/MacTileTests"
        )
    ]
)
