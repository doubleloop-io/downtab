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
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
        // The updater, the only runtime dependency (ADR 0005): pinned exactly, so every release ships a reviewed version.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        // Pure Switcher logic: must not import AppKit, ApplicationServices (AX) or private APIs.
        .target(name: "SwitcherCore", swiftSettings: strictSettings),
        // Adapters that receive callbacks or run on other threads. Nonisolated by default, so a closure
        // handed to a C API cannot silently become main-actor and trap at run time: touching main-actor
        // state from it is a compile error.
        .target(name: "BackgroundAdapters", dependencies: ["SwitcherCore"], swiftSettings: strictSettings),
        // The app is AppKit glue: main-actor by default. Thread-crossing code belongs in BackgroundAdapters.
        .executableTarget(
            name: "Downtab",
            dependencies: ["SwitcherCore", "BackgroundAdapters", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: strictSettings + [.defaultIsolation(MainActor.self)],
            // `make bundle` copies Sparkle.framework into Contents/Frameworks; SwiftPM adds no rpath to find it there.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        // Separate from the app: it must work when Downtab was killed with native ⌘Tab and ⌘` off.
        .executableTarget(
            name: "RestoreCommandTab", dependencies: ["SwitcherCore", "BackgroundAdapters"],
            swiftSettings: strictSettings),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"], swiftSettings: strictSettings),
        .testTarget(
            name: "BackgroundAdaptersTests", dependencies: ["BackgroundAdapters", "SwitcherCore"],
            swiftSettings: strictSettings),
    ]
)
