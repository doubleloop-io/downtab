import SwitcherCore
import Testing

@Test func appWithTwoWindowsShowsTheBadgeWithTheCount() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Safari", windows: [.window(in: [1]), .window(in: [1])])],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "Safari") == 2)
}

@Test func appWithASingleWindowShowsNoBadge() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari", windows: [.window(in: [1])])], currentSpaces: [1])

    #expect(opened(on: desktop).state.windowCountBadge(of: "Safari") == nil)
}

@Test func appWithNoWindowsShowsNoBadge() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Zoom")])

    #expect(opened(on: desktop).state.windowCountBadge(of: "Zoom") == nil)
}

@Test func windowsInOtherSpacesDoNotCountTowardsTheBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Code", windows: [.window(in: [1]), .unlisted(in: [2])])],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "Code") == nil)
}

@Test func minimizedWindowsInOtherSpacesDoNotCountTowardsTheBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("TextEdit", windows: [.window(in: [1]), .window(in: [2], isMinimized: true)])],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "TextEdit") == nil)
}

@Test func windowsInTheCurrentSpaceOfEveryDisplayCountTowardsTheBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Safari", windows: [.window(in: [1]), .window(in: [5])])],
        currentSpaces: [1, 5]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "Safari") == 2)
}

@Test func windowsInNoSpaceAndFullScreenWindowsCountTowardsTheBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Safari", windows: [.window(in: []), .window(in: [7], isFullScreen: true)])],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "Safari") == 2)
}
