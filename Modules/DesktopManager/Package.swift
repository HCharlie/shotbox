// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopManager",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DesktopManager", targets: ["DesktopManager"])],
    targets: [
        .target(name: "DesktopManager", path: "Sources/DesktopManager"),
        .testTarget(name: "DesktopManagerTests",
                    dependencies: ["DesktopManager"],
                    path: "Tests/DesktopManagerTests"),
    ]
)
