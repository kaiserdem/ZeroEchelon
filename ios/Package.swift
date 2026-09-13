// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZeroEchelonKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ZeroEchelonKit", targets: ["ZeroEchelonKit"]),
    ],
    targets: [
        .target(
            name: "ZeroEchelonKit",
            path: "Sources/ZeroEchelonKit"
        ),
        .testTarget(
            name: "ZeroEchelonKitTests",
            dependencies: ["ZeroEchelonKit"],
            path: "Tests/ZeroEchelonKitTests"
        ),
    ]
)
