// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MueCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "MueCore", targets: ["MueCore"]),
    ],
    targets: [
        .target(name: "MueCore"),
        .testTarget(name: "MueCoreTests", dependencies: ["MueCore"]),
    ]
)
