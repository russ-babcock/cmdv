// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CmdV",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "CmdV", targets: ["CmdV"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.11.0"))
    ],
    targets: [
        .executableTarget(
            name: "CmdV",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/CmdV"
        ),
        .testTarget(
            name: "CmdVTests",
            dependencies: ["CmdV"],
            path: "Tests/CmdVTests"
        )
    ]
)
