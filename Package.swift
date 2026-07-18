// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenCodeWebMenu",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "opencode-web-menu", targets: ["OpenCodeWebMenu"]),
    ],
    targets: [
        .executableTarget(name: "OpenCodeWebMenu"),
        .testTarget(name: "OpenCodeWebMenuTests", dependencies: ["OpenCodeWebMenu"]),
    ]
)
