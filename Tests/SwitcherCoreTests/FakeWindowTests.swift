import SwitcherCore
import Testing

@Test func elementsThatAreNotWindowsDoNotCountTowardsTheBadge() {
    let finderDesktop = DesktopWindow.listed(role: "AXScrollArea", subrole: nil, hasID: false)
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Finder", windows: [.window(in: [1]), .window(in: [1]), .window(in: [1]), finderDesktop])],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "Finder") == 3)
}

@Test func dialogsWithoutAWindowOrATitleAndOtherSubrolesDoNotCountTowardsTheBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular(
                "cmux",
                windows: [
                    .window(in: [1]),
                    .listed(role: "AXWindow", subrole: "AXDialog", title: "Item-0", hasID: false),
                    .listed(role: "AXWindow", subrole: "AXDialog", title: ""),
                    .listed(role: "AXWindow", subrole: "AXUnknown", title: ""),
                    .listed(role: "AXHelpTag", subrole: nil),
                ]
            )
        ],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "cmux") == nil)
}

@Test func aTitledDialogCountsTowardsTheBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [
            .regular(
                "TextEdit",
                windows: [.window(in: [1]), .listed(role: "AXWindow", subrole: "AXDialog", title: "Untitled 2")]
            )
        ],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "TextEdit") == 2)
}

@Test func finderWindowListHoldsOneEntryPerWindowLeavingOutTheDesktopAndEmptyElements() {
    // Accessibility reports a Finder window with tabs as a single window titled after one tab.
    let windowWithTabs = DesktopWindow.window("Documents")
    let finderDesktop = DesktopWindow.listed(role: "AXScrollArea", subrole: nil, hasID: false)
    let emptyElement = DesktopWindow.listed(role: "", subrole: nil, hasID: false)
    var (switcher, desktop) = openedOn(
        .regular("Finder", windows: [windowWithTabs, .window("Downloads"), finderDesktop, emptyElement])
    )

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.windowListTitles == ["Documents", "Downloads"])
}

@Test func downDoesNothingOnAnAppWhoseOtherWindowsAreFakeDialogs() {
    let fakeDialogs: [DesktopWindow] = [
        .listed(role: "AXWindow", subrole: "AXDialog", title: "Item-0", hasID: false),
        .listed(role: "AXWindow", subrole: "AXDialog", title: "Item-1", hasID: false),
        .listed(role: "AXWindow", subrole: "AXDialog", title: ""),
    ]
    var (switcher, desktop) = openedOn(.regular("cmux", windows: [.window()] + fakeDialogs))
    let before = switcher.state

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state == before)
}

@Test func aMinimizedWindowInAnotherSpaceReportedAsADialogIsLeftOutOfTheWindowList() {
    // Spike: TextEdit reports its minimized window of another Space as a titled `AXDialog`.
    let minimizedElsewhere = DesktopWindow.listed(
        role: "AXWindow", subrole: "AXDialog", title: "Notes.txt", in: [2], isMinimized: true
    )
    var (switcher, desktop) = openedOn(
        .regular("TextEdit", windows: [.window("A", in: [1]), .window("B", in: [1]), minimizedElsewhere])
    )

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.windowListTitles == ["A", "B"])
}

@Test func aMinimizedWindowInAnotherSpaceReportedAsADialogDoesNotCountTowardsTheBadge() {
    let minimizedElsewhere = DesktopWindow.listed(
        role: "AXWindow", subrole: "AXDialog", title: "Notes.txt", in: [2], isMinimized: true
    )
    let desktop = DesktopSnapshot.with(
        apps: [.regular("TextEdit", windows: [.window(in: [1]), minimizedElsewhere])],
        currentSpaces: [1]
    )

    #expect(opened(on: desktop).state.windowCountBadge(of: "TextEdit") == nil)
}
