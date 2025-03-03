// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MutantInjector",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "MutantInjector",
            targets: ["MutantInjector"]),
    ],
    targets: [
        .target(
            name: "MutantInjector",
            dependencies: []),
        .testTarget(
            name: "MutantInjectorTests",
            dependencies: ["MutantInjector"]),
    ]
)
