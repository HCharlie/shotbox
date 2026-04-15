// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HistoryStore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "HistoryStore", targets: ["HistoryStore"])],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3"),
    ],
    targets: [
        .target(name: "HistoryStore",
                dependencies: ["SharedModels", .product(name: "GRDB", package: "GRDB.swift")],
                path: "Sources/HistoryStore"),
        .testTarget(name: "HistoryStoreTests",
                    dependencies: ["HistoryStore"],
                    path: "Tests/HistoryStoreTests"),
    ]
)
