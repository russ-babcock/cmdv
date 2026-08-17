// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CmdV",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "CmdV", targets: ["CmdV"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.11.0")),
        // 2.7.2 is the floor, not 2.6.x: CVE-2025-10015 lets a local attacker
        // register Sparkle's Downloader XPC service globally and inherit the
        // host app's TCC permissions, and it is fixed in 2.7.2. CmdV holds
        // Accessibility, so that inheritance would be worth a lot to an
        // attacker. Package.resolved pins a newer version, but the floor is
        // what a fresh resolve is permitted to fall back to.
        .package(url: "https://github.com/sparkle-project/Sparkle", .upToNextMajor(from: "2.7.2"))
    ],
    targets: [
        .executableTarget(
            name: "CmdV",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CmdV",
            // The menu bar art. Note this is the target's own resource folder,
            // distinct from the top-level Resources/ that holds Info.plist and
            // AppIcon.icns — those are bundle scaffolding assembled by
            // Scripts/build.sh, not things SwiftPM knows about.
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CmdVTests",
            dependencies: ["CmdV"],
            path: "Tests/CmdVTests"
        )
    ]
)
