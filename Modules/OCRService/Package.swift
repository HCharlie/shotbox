// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OCRService",
    platforms: [.macOS(.v13)],
    products: [.library(name: "OCRService", targets: ["OCRService"])],
    dependencies: [
        .package(path: "../SharedModels"),
    ],
    targets: [
        .target(name: "OCRService",
                dependencies: ["SharedModels"],
                path: "Sources/OCRService"),
        .testTarget(name: "OCRServiceTests",
                    dependencies: ["OCRService"],
                    path: "Tests/OCRServiceTests"),
    ]
)
