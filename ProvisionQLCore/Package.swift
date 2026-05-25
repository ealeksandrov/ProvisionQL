// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ProvisionQLCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "ProvisionQLCore",
            targets: ["ProvisionQLCore"]
        ),
        .library(
            name: "PreviewUI",
            targets: ["PreviewUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
    ],
    targets: [
        .target(
            name: "ProvisionQLCore",
            dependencies: ["ZIPFoundation"],
            path: "Sources"
        ),
        .target(
            name: "PreviewUI",
            dependencies: ["ProvisionQLCore"],
            path: "PreviewUI"
        ),
        .testTarget(
            name: "ProvisionQLCoreTests",
            dependencies: ["ProvisionQLCore"],
            path: "Tests",
            resources: [
                .process("Fixtures")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
