// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaptureEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CaptureEngine", targets: ["CaptureEngine"])],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(url: "https://github.com/sindresorhus/Gifski.git", from: "2.2.0"),
    ],
    targets: [
        .target(name: "CaptureEngine",
                dependencies: ["SharedModels", "Gifski"],
                path: "Sources/CaptureEngine"),
        .testTarget(name: "CaptureEngineTests",
                    dependencies: ["CaptureEngine"],
                    path: "Tests/CaptureEngineTests"),
    ]
)
