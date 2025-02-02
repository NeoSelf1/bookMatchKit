// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BookMatchKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "BookMatchKit",
            targets: ["BookMatchKit"]
        ),
        .library(
            name: "BookMatchCore",
            targets: ["BookMatchCore"]
        ),
        .library(
            name: "BookMatchAPI",
            targets: ["BookMatchAPI"]
        ),
        .library(
            name: "BookMatchStrategy",
            targets: ["BookMatchStrategy"]
        )
    ],
    targets: [
            .target(
                name: "BookMatchCore",
                dependencies: []
            ),
            
            .target(
                name: "BookMatchAPI",
                dependencies: ["BookMatchCore"]
            ),
            
            .target(
                name: "BookMatchStrategy",
                dependencies: ["BookMatchCore"]
            ),
            
            .target(
                name: "BookMatchKit",
                dependencies: [
                    "BookMatchCore",
                    "BookMatchAPI",
                    "BookMatchStrategy"
                ]
            ),
        ]
)
