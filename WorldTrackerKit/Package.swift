// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorldTrackerKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "WorldTrackerKit", targets: ["WorldTrackerKit"])
    ],
    targets: [
        .target(
            name: "WorldTrackerKit",
            resources: [.copy("GeoData")]
        ),
        .testTarget(
            name: "WorldTrackerKitTests",
            dependencies: ["WorldTrackerKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
