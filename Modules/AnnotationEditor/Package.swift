// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnnotationEditor",
    platforms: [.macOS(.v13)],
    products: [.library(name: "AnnotationEditor", targets: ["AnnotationEditor"])],
    dependencies: [
        .package(path: "../SharedModels"),
    ],
    targets: [
        .target(name: "AnnotationEditor",
                dependencies: ["SharedModels"],
                path: "Sources/AnnotationEditor"),
        .testTarget(name: "AnnotationEditorTests",
                    dependencies: ["AnnotationEditor"],
                    path: "Tests/AnnotationEditorTests"),
    ]
)
