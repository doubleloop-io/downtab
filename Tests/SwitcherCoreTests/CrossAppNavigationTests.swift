import SwitcherCore
import Testing

@Test func rightAtAppLevelSelectsTheNextApp() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.isAtAppLevel)
}

@Test func rightAtAppLevelOnTheLastAppWrapsToTheFirst() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari"])
    var switcher = opened(on: desktop)

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
}

@Test func leftAtAppLevelSelectsThePreviousApp() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)

    switcher.handle(.leftPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
    #expect(switcher.state.isAtAppLevel)
}

@Test func leftAtAppLevelOnTheFirstAppWrapsToTheLast() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)
    switcher.handle(.leftPressed, desktop: desktop)

    switcher.handle(.leftPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test(arguments: [SwitcherEvent.leftPressed, .rightPressed])
func arrowsWhileClosedLeaveTheSwitcherClosed(arrow: SwitcherEvent) {
    var switcher = Switcher()

    let effect = switcher.handle(arrow, desktop: .with(mru: ["Mail", "Safari"]))

    #expect(switcher.state == .closed)
    #expect(effect == nil)
}

@Test func rightAtWindowLevelOpensTheNextAppsWindowListOnItsFirstWindow() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes", windows: [.window("N1"), .window("N2")]),
    ])

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.windowListTitles == ["N1", "N2"])
    #expect(switcher.state.selectedWindowTitle == "N1")
}

@Test(arguments: [0, 1])
func rightAtWindowLevelOntoAnAppWithFewerThanTwoWindowsSelectsItWithoutAWindowList(windowCount: Int) {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes", windows: (0..<windowCount).map { _ in .window() }),
    ])

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.windowListTitles == nil)
    #expect(!switcher.state.isAtAppLevel)
}

@Test func rightPastAnAppWithoutAWindowListReopensTheNextAppsWindowList() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes"),
        .regular("Mail", windows: [.window("M1"), .window("M2")]),
    ])
    switcher.handle(.rightPressed, desktop: desktop)

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
    #expect(switcher.state.windowListTitles == ["M1", "M2"])
}

@Test func rightAtWindowLevelOnTheLastAppWrapsToTheFirstAppsWindowList() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Frontmost", windows: [.window("Current"), .window("Behind")]),
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
    ])
    var switcher = opened(on: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.rightPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Frontmost")
    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test func leftAtWindowLevelOpensThePreviousAppsWindowList() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes", windows: [.window("N1"), .window("N2")]),
    ])
    switcher.handle(.rightPressed, desktop: desktop)

    switcher.handle(.leftPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.selectedWindowTitle == "S1")
}

@Test func leftAtWindowLevelOnTheFirstAppWrapsToTheLastAppsWindowList() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Frontmost", windows: [.window("Current"), .window("Behind")]),
        .regular("Safari"),
        .regular("Notes", windows: [.window("N1"), .window("N2")]),
    ])
    var switcher = opened(on: desktop)
    switcher.handle(.leftPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.leftPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.selectedWindowTitle == "N1")
}

@Test func appShortcutAtWindowLevelReturnsToAppLevelOnTheNextApp() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes", windows: [.window("N1"), .window("N2")]),
    ])

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.isAtAppLevel)
}

@Test func appShortcutAtWindowLevelWithoutAWindowListReturnsToAppLevelOnTheNextApp() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes"),
        .regular("Mail", windows: [.window("M1"), .window("M2")]),
    ])
    switcher.handle(.rightPressed, desktop: desktop)

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
    #expect(switcher.state.isAtAppLevel)
}

@Test(arguments: [SwitcherEvent.modifierReleased, .enterPressed])
func confirmingAtWindowLevelWithoutAWindowListActivatesTheSelectedApp(confirm: SwitcherEvent) {
    let app = DesktopApp.regular("Notes", windows: [.window()])
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window(), .window()]), app])
    switcher.handle(.rightPressed, desktop: desktop)

    let effect = switcher.handle(confirm, desktop: desktop)

    #expect(effect == .activateApp(app.id))
}

@Test func upAtWindowLevelWithoutAWindowListReturnsToAppLevelOnTheSameApp() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window(), .window()]), .regular("Notes"),
    ])
    switcher.handle(.rightPressed, desktop: desktop)

    switcher.handle(.upPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.isAtAppLevel)
}

@Test func downAtWindowLevelWithoutAWindowListDoesNothing() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window(), .window()]), .regular("Notes"),
    ])
    switcher.handle(.rightPressed, desktop: desktop)
    let before = switcher.state

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state == before)
}
