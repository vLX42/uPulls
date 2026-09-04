// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "uPulls",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "uPulls",
            path: "Sources/uPulls"
        ),
        .testTarget(
            name: "uPullsTests",
            dependencies: ["uPulls"],
            path: "Tests/uPullsTests"
        )
    ]
)
