// swift-tools-version: 6.0
import PackageDescription

// Módulos de la app iOS. Se compilan con Xcode (ver project.yml y .github/workflows/ci.yml).
let package = Package(
    name: "RicoKit",
    defaultLocalization: "es",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RicoKit", targets: ["Modelos", "DesignSystem", "Visitas", "Cuenta"])
    ],
    dependencies: [
        .package(path: "../RicoCore"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.20.0")
    ],
    targets: [
        .target(name: "Modelos", dependencies: ["RicoCore"]),
        .target(name: "DesignSystem", dependencies: ["RicoCore"], resources: [.process("Resources")]),
        .target(name: "Visitas", dependencies: ["RicoCore", "Modelos", "DesignSystem"], resources: [.process("Resources")]),
        .target(
            name: "Cuenta",
            dependencies: [
                "RicoCore",
                "Modelos",
                "DesignSystem",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            resources: [.process("Resources")]
        )
    ]
)
