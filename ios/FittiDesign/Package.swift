// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FittiDesign",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FittiDesign", targets: ["FittiDesign"])
    ],
    targets: [
        .target(name: "FittiDesign"),
        .testTarget(name: "FittiDesignTests", dependencies: ["FittiDesign"])
    ]
)
