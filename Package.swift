// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Screenshots",
    platforms: [.macOS("10.15")],
    products: [
        .library(
            name: "Screenshots",
            type: .dynamic,
            targets: ["Screenshots"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Screenshots",
            dependencies: [])
    ]
)
