// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "TimeZoneBar",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "TimeZoneCore", targets: ["TimeZoneCore"]),
        .executable(name: "TimeZoneBar", targets: ["TimeZoneBar"])
    ],
    targets: [
        .target(name: "TimeZoneCore"),
        .executableTarget(
            name: "TimeZoneBar",
            dependencies: ["TimeZoneCore"]
        ),
        .testTarget(
            name: "TimeZoneCoreTests",
            dependencies: ["TimeZoneCore"]
        )
    ]
)
