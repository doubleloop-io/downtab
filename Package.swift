// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Downtab",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Lint only (`make lint`): pinned exactly so local runs and CI apply the same rules.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
    ],
    targets: [
        // Pure Switcher logic: must not import AppKit, ApplicationServices (AX) or private APIs.
        .target(name: "SwitcherCore"),
        .executableTarget(name: "Downtab", dependencies: ["SwitcherCore"]),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"]),
    ]
)
