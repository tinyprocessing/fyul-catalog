// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CatalogKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CatalogCore", targets: ["CatalogCore"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "ProductsFeature", targets: ["ProductsFeature"]),
        .library(name: "CatalogAccessibility", targets: ["CatalogAccessibility"]),
    ],
    targets: [
        .target(name: "CatalogAccessibility"),
        .target(name: "CatalogCore"),
        .target(name: "DesignSystem"),
        .target(
            name: "ProductsFeature",
            dependencies: ["CatalogCore", "DesignSystem", "CatalogAccessibility"],
            resources: [.process("Resources")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
