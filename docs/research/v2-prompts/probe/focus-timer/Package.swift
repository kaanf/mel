// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FocusTimer",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "FocusTimer", dependencies: ["TimerCore", "SessionStore"]),
        .target(name: "TimerCore"),
        .target(name: "SessionStore", dependencies: ["TimerCore"]),
        .testTarget(name: "TimerCoreTests", dependencies: ["TimerCore"]),
    ]
)
