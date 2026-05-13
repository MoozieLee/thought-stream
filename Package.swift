// swift-tools-version: 6.2
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
        )
    ]
)
