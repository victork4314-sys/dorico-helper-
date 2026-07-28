// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DoricoXboxBridge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DoricoBridgeCore", targets: ["DoricoBridgeCore"]),
        .executable(name: "DoricoXboxBridge", targets: ["DoricoXboxBridge"])
    ],
    targets: [
        .target(name: "DoricoBridgeCore"),
        .executableTarget(
            name: "DoricoXboxBridge",
            dependencies: ["DoricoBridgeCore"]
        ),
        .testTarget(
            name: "DoricoBridgeCoreTests",
            dependencies: ["DoricoBridgeCore"]
        )
    ]
)
