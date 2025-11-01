// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Mist",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "Mist", targets: ["Mist"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.4.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.8.0"),
    ],
    targets: [
        .target(
            name: "Mist",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Leaf", package: "leaf"),
            ]
        ),
        .testTarget(
            name: "MistTests",
            dependencies: [
                "Mist",
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
