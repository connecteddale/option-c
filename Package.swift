// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OptionC",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OptionC", targets: ["OptionC"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.11.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "OptionC",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/OptionC",
            exclude: ["Resources/Info.plist"]
        )
    ]
)
