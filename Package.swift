// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ProjectPlanner",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ProjectPlanner", targets: ["ProjectPlanner"])
    ],
    targets: [
        .executableTarget(name: "ProjectPlanner")
    ]
)
