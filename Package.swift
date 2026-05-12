// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "NightShepherd",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "NightShepherd",
            path: "Sources/NightShepherd",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
