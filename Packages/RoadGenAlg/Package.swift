// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RoadGenAlg",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RoadGenAlg",
            targets: ["RoadGenAlg"]),
    ],
    dependencies: [
        // Add the Swift Collections dependency here
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RoadGenAlg",
            dependencies: [
                // Add the specific products you want to use from Swift Collections
                .product(name: "Collections", package: "swift-collections")
            ]),
        .testTarget(
            name: "RoadGenAlgTests",
            dependencies: ["RoadGenAlg",
                           .product(name: "Collections", package: "swift-collections")]
        ),
    ]
)
