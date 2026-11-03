import SwitcherCore
import Testing

/// Safari is the Frontmost app, with the given windows front to back.
private func desktopWithFrontmostSafari(windows titles: [String]) -> DesktopSnapshot {
    DesktopSnapshot.with(apps: [.regular("Safari", windows: titles.map { .window($0) }), .regular("Notes")])
}

@Test func windowShortcutOpensTheFrontmostAppsWindowListOnTheSecondWindow() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()

    switcher.handle(.windowShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.windowListTitles == ["Current", "Behind", "Back"])
    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test func windowShortcutPressedAgainAdvancesInTheWindowList() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    switcher.handle(.windowShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Back")
}

@Test func windowShortcutPastTheLastWindowWrapsToTheFirst() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    switcher.handle(.windowShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Current")
}

@Test func shiftWindowShortcutGoesBackInTheWindowList() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    switcher.handle(.shiftWindowShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test func shiftWindowShortcutBeforeTheFirstWindowWrapsToTheLast() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)
    switcher.handle(.shiftWindowShortcutPressed, desktop: desktop)

    switcher.handle(.shiftWindowShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Back")
}

@Test func shiftWindowShortcutOpensTheFrontmostAppsWindowListOnTheBackmostWindow() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()

    switcher.handle(.shiftWindowShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.selectedWindowTitle == "Back")
}

@Test func downAfterTheWindowShortcutSelectsTheNextWindow() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Back")
}

@Test func upFromTheFirstWindowAfterTheWindowShortcutReturnsToAppLevelOnTheFrontmostApp() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)
    switcher.handle(.upPressed, desktop: desktop)

    switcher.handle(.upPressed, desktop: desktop)

    #expect(switcher.state.isAtAppLevel)
    #expect(switcher.state.selectedName == "Safari")
}

@Test func appShortcutAfterTheWindowShortcutMovesToTheNextAppAtAppLevel() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.isAtAppLevel)
    #expect(switcher.state.selectedName == "Notes")
}

@Test func rightAfterTheWindowShortcutMovesToTheNextAppStayingAtWindowLevel() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]),
        .regular("Notes", windows: [.window("First"), .window("Second")]),
    ])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.selectedWindowTitle == "First")
}

@Test func windowShortcutAtAppLevelDoesNothing() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)
    switcher.handle(.appShortcutPressed, desktop: desktop)
    let atAppLevel = switcher.state

    switcher.handle(.windowShortcutPressed, desktop: desktop)

    #expect(switcher.state == atAppLevel)
}

@Test(arguments: [SwitcherEvent.modifierReleased, .enterPressed])
func confirmingAfterTheWindowShortcutBringsOnlyTheSelectedWindowToTheFront(confirm: SwitcherEvent) throws {
    let behind = DesktopWindow.window("Behind")
    let safari = DesktopApp.regular("Safari", windows: [.window("Current"), behind])
    let desktop = DesktopSnapshot.with(apps: [safari, .regular("Notes")])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    let effect = switcher.handle(confirm, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .bringWindowToFront(try #require(behind.id), of: safari.id))
}

@Test func escapeAfterTheWindowShortcutCancels() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)

    let effect = switcher.handle(.escapePressed, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .noChange)
}

@Test(arguments: [SwitcherEvent.windowShortcutPressed, .shiftWindowShortcutPressed], [0, 1])
func windowShortcutWithFewerThanTwoWindowsLeavesTheSwitcherClosed(shortcut: SwitcherEvent, windowCount: Int) {
    let desktop = desktopWithFrontmostSafari(windows: (0..<windowCount).map { "Window \($0)" })
    var switcher = Switcher()

    let effect = switcher.handle(shortcut, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == nil)
}

@Test func windowShortcutWithNoFrontmostAppLeavesTheSwitcherClosed() {
    let desktop = DesktopSnapshot(
        apps: [], mruOrder: [], currentSpaces: [], isActiveSpaceFullScreen: false, frontmostApp: nil)
    var switcher = Switcher()

    switcher.handle(.windowShortcutPressed, desktop: desktop)

    #expect(switcher.state == .closed)
}
