// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Terrain",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "Terrain",
            targets: ["Terrain"]),
    ],
    targets: [
        .target(
            name: "Terrain"),
        .testTarget(
            name: "TerrainTests",
            dependencies: ["Terrain"]
        ),
    ]
)

