// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacYT",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacYT",
            targets: ["MacYT"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacYT",
            path: "MacYT",
            exclude: [
                "Assets.xcassets"
            ]
        )
    ]
)
