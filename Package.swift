// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sova",
    platforms: [.macOS(.v15)],
    targets: [
        // Decisions and the only code that touches root. No AppKit.
        .target(name: "SovaCore"),
        // Menu bar, battery events, notifications, launch.
        .executableTarget(name: "Sova", dependencies: ["SovaCore"]),
        .testTarget(name: "SovaCoreTests", dependencies: ["SovaCore"]),
    ]
)
