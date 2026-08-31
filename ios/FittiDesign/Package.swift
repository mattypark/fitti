// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FittiDesign",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FittiDesign", targets: ["FittiDesign"]),
        .library(name: "FittiEngine", targets: ["FittiEngine"]),
    ],
    targets: [
        .target(name: "FittiDesign"),
        // Pure logic, no UIKit and no SwiftUI, so it compiles and tests on macOS.
        // That is the point: outfit scoring can be verified in a second from the
        // command line rather than only inside a simulator.
        .target(name: "FittiEngine"),
        .testTarget(name: "FittiDesignTests", dependencies: ["FittiDesign"]),
        .testTarget(name: "FittiEngineTests", dependencies: ["FittiEngine"]),
    ]
)
