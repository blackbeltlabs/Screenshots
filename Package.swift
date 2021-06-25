// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Screenshots",
    platforms: [.macOS("10.13")],
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
