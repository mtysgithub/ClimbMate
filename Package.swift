// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClimbMate",
    products: [
        .library(name: "ClimbMateCore", targets: ["ClimbMateCore"]),
        .library(name: "ClimbMateCoreiOS", targets: ["ClimbMateCoreiOS"]),
        .library(name: "ClimbMateCoreWindows", targets: ["ClimbMateCoreWindows"]),
        .executable(name: "ClimbMateWindowsCLI", targets: ["ClimbMateWindowsCLI"])
    ],
    targets: [
        .target(name: "ClimbMateCore"),
        .target(name: "ClimbMateCoreiOS", dependencies: ["ClimbMateCore"]),
        .target(name: "ClimbMateCoreWindows", dependencies: ["ClimbMateCore"]),
        .executableTarget(name: "ClimbMateWindowsCLI", dependencies: ["ClimbMateCoreWindows", "ClimbMateCore"]),
        .testTarget(name: "ClimbMateCoreTests", dependencies: ["ClimbMateCore"]),
        .testTarget(name: "ClimbMateCoreWindowsTests", dependencies: ["ClimbMateCoreWindows", "ClimbMateCore"])
    ]
)
