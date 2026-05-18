// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThoughtStream",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ThoughtStreamCore", targets: ["ThoughtStreamCore"]),
        .executable(name: "ThoughtStreamApp", targets: ["ThoughtStreamApp"]),
        .executable(name: "thought", targets: ["thought"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "ThoughtStreamCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "ThoughtStreamApp",
            dependencies: ["ThoughtStreamCore"]
        ),
        .executableTarget(
            name: "thought",
            dependencies: ["ThoughtStreamCore"]
        ),
        .testTarget(
            name: "ThoughtStreamCoreTests",
            dependencies: [
                "ThoughtStreamCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
