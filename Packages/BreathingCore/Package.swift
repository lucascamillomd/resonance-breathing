// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BreathingCore",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "BreathingCore", targets: ["BreathingCore"]),
    ],
    targets: [
        .target(name: "BreathingCore"),
        .testTarget(name: "BreathingCoreTests", dependencies: ["BreathingCore"]),
    ]
)
