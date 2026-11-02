// swift-tools-version: 6.0
import PackageDescription

/// Feature modules. `scripts/new-feature.sh <Name>` appends here.
let features = ["ProductsFeature"]

let package = Package(
    name: "CatalogKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CatalogCore", targets: ["CatalogCore"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "CatalogAccessibility", targets: ["CatalogAccessibility"]),
    ] + features.map { .library(name: $0, targets: [$0]) },
    targets: [
        .target(name: "CatalogAccessibility"),
        .target(name: "CatalogCore"),
        .target(name: "DesignSystem"),
    ] + features.map {
        .target(
            name: $0,
            dependencies: ["CatalogCore", "DesignSystem", "CatalogAccessibility"],
            resources: [.process("Resources")]
        )
    },
    swiftLanguageModes: [.v6]
)
