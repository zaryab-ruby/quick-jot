// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickJot",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuickJot",
            path: "Sources/QuickJot"
        ),
        .testTarget(
            name: "QuickJotTests",
            dependencies: ["QuickJot"],
            path: "Tests/QuickJotTests"
        ),
    ]
)
