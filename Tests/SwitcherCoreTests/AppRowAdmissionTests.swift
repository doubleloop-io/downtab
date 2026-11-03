import SwitcherCore
import Testing

@Test func appWhoseWindowsAreAllInOtherSpacesIsLeftOut() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Mail", windows: [.window(in: [1])]), .regular("Vivaldi", windows: [.unlisted(in: [2])])],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["Mail"])
}

@Test func appWithWindowsInTheCurrentSpaceAppears() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Mail", windows: [.window(in: [1])])], currentSpaces: [1])

    #expect(appRowNames(of: desktop) == ["Mail"])
}

@Test func appWithNoWindowsAppears() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Mail", windows: [.window(in: [1])]), .regular("Zoom")])

    #expect(appRowNames(of: desktop) == ["Mail", "Zoom"])
}

@Test func appWithWindowsInTheCurrentSpaceOfAnyDisplayAppears() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Mail", windows: [.window(in: [1])]),
            .regular("Safari", windows: [.window(in: [5])]),
            .regular("Notes", windows: [.unlisted(in: [2])]),
        ],
        currentSpaces: [1, 5]
    )

    #expect(appRowNames(of: desktop) == ["Mail", "Safari"])
}

@Test func twoInstancesOfTheSameAppAreSeparateEntriesAdmittedOnTheirOwnWindows() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Chrome", processIdentifier: 1, windows: [.window(in: [1])]),
            .regular("Chrome", processIdentifier: 2, windows: [.window(in: [1])]),
            .regular("Chrome", processIdentifier: 3, windows: [.unlisted(in: [2])]),
        ],
        currentSpaces: [1]
    )

    let switcher = opened(on: desktop)

    #expect(switcher.state.appRowIDs == [1, 2].map { AppID(processIdentifier: $0) })
}

@Test func appWithAWindowInTheCurrentSpaceAndOneElsewhereAppears() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Code", windows: [.window(in: [1]), .unlisted(in: [2])])],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["Code"])
}

@Test func appsWhoseWindowsBelongToNoSpaceAppear() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("zoom.us", windows: [.unlisted(in: [])]),
            .regular("iTerm2", windows: [.unlisted(in: []), .unlisted(in: [])]),
        ],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["zoom.us", "iTerm2"])
}

@Test func appWithAWindowInSeveralSpacesIncludingTheCurrentOneAppears() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("iTerm2", windows: [.unlisted(in: [4, 3, 1])])],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["iTerm2"])
}

@Test func hiddenAppAppearsEvenWithWindowsOnlyInOtherSpaces() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Safari", isHidden: true, windows: [.unlisted(in: [2])])],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["Safari"])
}

@Test func appWhoseOnlyWindowIsFullScreenAppears() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Mail", windows: [.window(in: [1])]),
            .regular("Safari", windows: [.unlisted(in: [7], isFullScreen: true)]),
        ],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["Mail", "Safari"])
}

@Test func openingFromAFullScreenAppShowsAllApps() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Safari", windows: [.window(in: [7], isFullScreen: true)]),
            .regular("Mail", windows: [.unlisted(in: [1])]),
            .regular("Notes", windows: [.unlisted(in: [2])]),
        ],
        currentSpaces: [7],
        isActiveSpaceFullScreen: true
    )

    #expect(appRowNames(of: desktop) == ["Safari", "Mail", "Notes"])
}

/// Activation can bring an app forward without leaving the full-screen Space.
@Test func inAFullScreenSpaceAllAppsShowEvenWhenTheFrontmostAppIsNotFullScreen() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Miro", windows: [.unlisted(in: [1])]),
            .regular("Safari", windows: [.window(in: [7], isFullScreen: true)]),
            .regular("Notes", windows: [.unlisted(in: [2])]),
        ],
        currentSpaces: [7],
        isActiveSpaceFullScreen: true
    )

    #expect(appRowNames(of: desktop) == ["Miro", "Safari", "Notes"])
}

@Test func aFullScreenWindowOfAnotherAppDoesNotShowAllApps() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular("Mail", windows: [.window(in: [1])]),
            .regular("Safari", windows: [.window(in: [7], isFullScreen: true)]),
            .regular("Notes", windows: [.unlisted(in: [2])]),
        ],
        currentSpaces: [1, 7]
    )

    #expect(appRowNames(of: desktop) == ["Mail", "Safari"])
}

@Test func smallServiceWindowsInOtherSpacesDoNotHideAnApp() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("zoom.us", windows: [.unlisted(in: [2], size: WindowSize(width: 60, height: 40))])],
        currentSpaces: [1]
    )

    #expect(appRowNames(of: desktop) == ["zoom.us"])
}

@Test func withNoCurrentSpaceKnownNoAppIsLeftOutForLivingInOtherSpaces() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Notes", windows: [.unlisted(in: [2])])], currentSpaces: [])

    #expect(appRowNames(of: desktop) == ["Notes"])
}
