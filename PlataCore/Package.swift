// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlataCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PlataCore", targets: ["PlataCore"])],
    targets: [
        .target(name: "PlataCore"),
        .testTarget(name: "PlataCoreTests", dependencies: ["PlataCore"])
    ]
)
