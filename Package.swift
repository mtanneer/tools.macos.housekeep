// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Housekeep",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HousekeepCore", targets: ["HousekeepCore"]),
        .executable(name: "housekeep", targets: ["housekeep"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "HousekeepCore"
        ),
        .executableTarget(
            name: "housekeep",
            dependencies: [
                "HousekeepCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "HousekeepCoreTests",
            dependencies: ["HousekeepCore"]
        ),
    ]
)
