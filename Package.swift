// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Downtab",
    platforms: [.macOS(.v15)],
    targets: [
        // Pure Switcher logic: must not import AppKit, ApplicationServices (AX) or private APIs.
        .target(name: "SwitcherCore"),
        .executableTarget(name: "Downtab", dependencies: ["SwitcherCore"]),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"]),
    ]
)
