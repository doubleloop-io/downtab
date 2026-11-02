// swift-tools-version:6.2
import PackageDescription

// Compiler-enforced guardrails, applied to every target.
let strictSettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "Downtab",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Lint only (`make lint`): pinned exactly so local runs and CI apply the same rules.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1")
    ],
    targets: [
        // Pure Switcher logic: must not import AppKit, ApplicationServices (AX) or private APIs.
        .target(name: "SwitcherCore", swiftSettings: strictSettings),
        // The app is AppKit glue: main-actor by default, so only background work needs annotating.
        .executableTarget(
            name: "Downtab",
            dependencies: ["SwitcherCore"],
            swiftSettings: strictSettings + [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"], swiftSettings: strictSettings),
    ]
)
