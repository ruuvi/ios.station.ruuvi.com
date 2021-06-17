// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCloud",
    platforms: [.macOS(.v10_15), .iOS(.v10)],
    products: [
        .library(
            name: "RuuviCloud",
            targets: ["RuuviCloud"]),
        .library(
            name: "RuuviCloudApi",
            targets: ["RuuviCloud"]),
        .library(
            name: "RuuviCloudPure",
            targets: ["RuuviCloud"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(url: "https://github.com/rinat-enikeev/BTKit", .upToNextMinor(from: "0.2.1")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviUser")
    ],
    targets: [
        .target(
            name: "RuuviCloud",
            dependencies: [
                "Future",
                "RuuviOntology",
                "RuuviUser"
            ]
        ),
        .target(
            name: "RuuviCloudApi",
            dependencies: [
                "RuuviCloud",
                "RuuviOntology",
                "Future",
                "BTKit"
            ]
        ),
        .target(
            name: "RuuviCloudPure",
            dependencies: [
                "RuuviCloud",
                "RuuviCloudApi",
                "RuuviOntology",
                "RuuviUser",
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviCloudTests",
            dependencies: ["RuuviCloud"])
    ]
)
