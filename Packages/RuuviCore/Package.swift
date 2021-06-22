// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCore",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviCore",
            targets: ["RuuviCore"]),
        .library(
            name: "RuuviCoreImage",
            targets: ["RuuviCoreImage"]),
        .library(
            name: "RuuviCoreLocation",
            targets: ["RuuviCoreLocation"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0"))
    ],
    targets: [
        .target(
            name: "RuuviCore",
            dependencies: []),
        .target(
            name: "RuuviCoreImage",
            dependencies: ["RuuviCore"]
        ),
        .target(
            name: "RuuviCoreLocation",
            dependencies: ["RuuviCore", "Future"]
        ),
        .testTarget(
            name: "RuuviCoreTests",
            dependencies: ["RuuviCore"])
    ]
)
