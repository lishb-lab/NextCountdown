// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NextCountdown",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NextCountdown", targets: ["NextCountdown"])
    ],
    targets: [
        .executableTarget(name: "NextCountdown")
    ]
)
