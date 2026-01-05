// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RoadGeneration",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RoadGeneration",
            targets: ["RoadGeneration"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(path: "../Terrain")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RoadGeneration",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Terrain", package: "Terrain")
            ]),
        .testTarget(
            name: "RoadGenerationTests",
            dependencies: [
                "RoadGeneration",
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
    ]
)
