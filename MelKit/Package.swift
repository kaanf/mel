// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MelKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MelSpec", targets: ["MelSpec"]),
        .library(name: "MelStorage", targets: ["MelStorage"]),
        .library(name: "MelAgent", targets: ["MelAgent"]),
        .library(name: "MelSystem", targets: ["MelSystem"]),
    ],
    targets: [
        .target(name: "MelSpec"),
        .target(name: "MelStorage", dependencies: ["MelSpec"]),
        .target(name: "MelAgent", dependencies: ["MelSpec"]),
        .target(name: "MelSystem"),
        .testTarget(name: "MelSpecTests", dependencies: ["MelSpec"]),
        .testTarget(name: "MelStorageTests", dependencies: ["MelStorage"]),
        .testTarget(name: "MelAgentTests", dependencies: ["MelAgent"], resources: [.copy("Fixtures")]),
        .testTarget(name: "MelSystemTests", dependencies: ["MelSystem"]),
    ],
    swiftLanguageModes: [.v6]
)
