// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StreamKit",
    products: [
        .library(
            name: "StreamKit",
            targets: ["StreamKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "4.5.0"),
    ],
    targets: [
        .target(
            name: "StreamKit",
            dependencies: ["PromiseKit"]
        ),
        .testTarget(
            name: "StreamKitTests",
            dependencies: ["StreamKit"]
        ),
    ]
)
