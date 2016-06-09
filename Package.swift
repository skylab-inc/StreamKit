import PackageDescription

let package = Package(
    name: "Reactive",
    dependencies: [
        .Package(url: "https://github.com/Zewo/Log.git", majorVersion: 0, minor: 8)
    ]
)
