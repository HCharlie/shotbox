// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaptureEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CaptureEngine", targets: ["CaptureEngine"])],
    dependencies: [
        .package(path: "../SharedModels"),
        // Gifski (sindresorhus/Gifski) is an Xcode app project, not an SPM package.
        // GIF encoding is handled via ImageIO instead.
    ],
    targets: [
        .target(name: "CaptureEngine",
                dependencies: ["SharedModels"],
                path: "Sources/CaptureEngine"),
        .testTarget(name: "CaptureEngineTests",
                    dependencies: ["CaptureEngine"],
                    path: "Tests/CaptureEngineTests"),
    ]
)
