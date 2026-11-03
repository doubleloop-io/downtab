import SwitcherCore
import Testing

/// Another app is the Frontmost app, so the Switcher opens with the app under test selected, then `↓` opens its
/// Window list on the first window.
private func windowListOf(_ app: DesktopApp) -> (Switcher, DesktopSnapshot) {
    let desktop = DesktopSnapshot.with(apps: [.regular("Frontmost"), app])
    var switcher = opened(on: desktop)
    switcher.handle(.downPressed, desktop: desktop)
    return (switcher, desktop)
}

@Test func minimizedWindowsGoAfterTheOthersKeepingTheirOrder() {
    let windows: [DesktopWindow] = [
        .window("Minimized front", isMinimized: true), .window("Front"), .window("Minimized back", isMinimized: true),
        .window("Back"),
    ]

    let (switcher, _) = windowListOf(.regular("TextEdit", windows: windows))

    #expect(switcher.state.windowListTitles == ["Front", "Back", "Minimized front", "Minimized back"])
}

@Test func minimizedWindowsOfOtherSpacesAreLeftOutButThoseOfTheCurrentSpaceOrOfNoSpaceStay() {
    let windows: [DesktopWindow] = [
        .window("Here"), .window("Minimized here", in: [1], isMinimized: true),
        .window("Minimized elsewhere", in: [2], isMinimized: true),
        .window("Minimized in no Space", isMinimized: true),
    ]

    let (switcher, _) = windowListOf(.regular("TextEdit", windows: windows))

    #expect(switcher.state.windowListTitles == ["Here", "Minimized here", "Minimized in no Space"])
}

@Test func windowListLabelsMinimizedAndFullScreenWindows() {
    let windows: [DesktopWindow] = [
        .window("Plain"), .window("Full", in: [3], isFullScreen: true), .window("Minimized", isMinimized: true),
    ]

    let (switcher, _) = windowListOf(.regular("TextEdit", windows: windows))

    #expect(switcher.state.windowListLabels == [[], [.fullScreen], [.minimized]])
}

@Test func everyWindowOfAHiddenAppIsLabelledHidden() {
    let windows: [DesktopWindow] = [.window("Plain"), .window("Minimized", isMinimized: true)]

    let (switcher, _) = windowListOf(.regular("TextEdit", isHidden: true, windows: windows))

    #expect(switcher.state.windowListLabels == [[.hidden], [.minimized, .hidden]])
}

@Test func openingFromAFullScreenAppShowsNoWindowListsNorBadges() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Safari", windows: [.window(in: [7], isFullScreen: true), .window(in: [1])]),
            .regular("TextEdit", windows: [.window(in: [7]), .window(in: [7])]),
        ],
        currentSpaces: [7]
    )
    var switcher = opened(on: desktop)

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.isAtAppLevel)
    #expect(switcher.state.windowCountBadge(of: "TextEdit") == nil)
    #expect(switcher.state.windowCountBadge(of: "Safari") == nil)
}

@Test func confirmingAMinimizedWindowAsksToRestoreIt() throws {
    let minimized = DesktopWindow.window("Minimized", isMinimized: true)
    let app = DesktopApp.regular("TextEdit", windows: [minimized, .window("Plain")])
    var (switcher, desktop) = windowListOf(app)
    switcher.handle(.downPressed, desktop: desktop)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(effect == .bringWindowToFront(try #require(minimized.id), of: app.id, restoring: [.unminimize]))
}

@Test func confirmingAWindowOfAHiddenAppAsksToUnhideTheApp() throws {
    let chosen = DesktopWindow.window("Chosen")
    let app = DesktopApp.regular("TextEdit", isHidden: true, windows: [chosen, .window("Other")])
    var (switcher, desktop) = windowListOf(app)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(effect == .bringWindowToFront(try #require(chosen.id), of: app.id, restoring: [.unhide]))
}

@Test func confirmingAMinimizedWindowOfAHiddenAppAsksForBoth() throws {
    let minimized = DesktopWindow.window("Minimized", isMinimized: true)
    let app = DesktopApp.regular("TextEdit", isHidden: true, windows: [minimized, .window("Plain")])
    var (switcher, desktop) = windowListOf(app)
    switcher.handle(.downPressed, desktop: desktop)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(effect == .bringWindowToFront(try #require(minimized.id), of: app.id, restoring: [.unminimize, .unhide]))
}

@Test func confirmingAPlainWindowAsksToRestoreNothing() throws {
    let chosen = DesktopWindow.window("Chosen")
    let app = DesktopApp.regular("TextEdit", windows: [chosen, .window("Other")])
    var (switcher, desktop) = windowListOf(app)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(effect == .bringWindowToFront(try #require(chosen.id), of: app.id, restoring: []))
}
