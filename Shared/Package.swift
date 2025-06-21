// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Shared",
            targets: ["Shared"]),
    ],
    targets: [
        .target(
            name: "Shared",
            path: "."
        )
    ]
)
