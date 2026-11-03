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
