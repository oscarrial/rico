// swift-tools-version: 6.0
import PackageDescription

// Lógica pura de Rico, sin frameworks de Apple: se compila y se prueba también en Linux.
let package = Package(
    name: "RicoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RicoCore", targets: ["RicoCore"])
    ],
    targets: [
        .target(name: "RicoCore"),
        .testTarget(name: "RicoCoreTests", dependencies: ["RicoCore"])
    ]
)
