// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IconForge",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "IconForge",
            targets: ["IconForge"]
        )
    ],
    targets: [
        .target(
            name: "IconForge",
            path: "Sources",
            exclude: [
                "Resources",
                "App",
            ],
            resources: [
                .copy("../Resources/Info.plist"),
            ]
        ),
        .testTarget(
            name: "IconForgeTests",
            dependencies: ["IconForge"],
            path: "Tests/IconForgeTests"
        )
    ]
)
