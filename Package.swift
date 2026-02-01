// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OptionC",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OptionC", targets: ["OptionC"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.11.0")
    ],
    targets: [
        .executableTarget(
            name: "OptionC",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/OptionC"
        )
    ]
)
