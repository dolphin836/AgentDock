// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentDock",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentDockCore", targets: ["AgentDockCore"]),
        .executable(name: "AgentDock", targets: ["AgentDock"]),
    ],
    targets: [
        .target(
            name: "AgentDockCore",
            resources: [.copy("Resources/agentdock-emit")]
        ),
        .executableTarget(name: "AgentDock", dependencies: ["AgentDockCore"]),
        .testTarget(name: "AgentDockCoreTests", dependencies: ["AgentDockCore"]),
    ]
)
