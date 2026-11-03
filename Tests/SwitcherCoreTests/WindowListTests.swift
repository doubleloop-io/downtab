import SwitcherCore
import Testing

/// Another app is the Frontmost app, so the Switcher opens with the app under test selected.
private func openedOn(_ app: DesktopApp) -> (Switcher, DesktopSnapshot) {
    let desktop = DesktopSnapshot.with(apps: [.regular("Frontmost"), app])
    return (opened(on: desktop), desktop)
}

@Test func downOnAnAppWithTwoWindowsOpensItsWindowListOnTheFirstWindow() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("A"), .window("B")]))

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.windowListTitles == ["A", "B"])
    #expect(switcher.state.selectedWindowTitle == "A")
}

@Test func windowListFollowsTheAppsFrontToBackOrderLeavingOutWindowsInOtherSpaces() {
    let windows: [DesktopWindow] = [.window("Front", in: [1]), .unlisted(in: [2]), .window("Middle"), .window("Back")]
    var (switcher, desktop) = openedOn(.regular("Safari", windows: windows))

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.windowListTitles == ["Front", "Middle", "Back"])
}

@Test func downAtWindowLevelSelectsTheNextWindowAndStopsAtTheLast() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("A"), .window("B"), .window("C")]))
    switcher.handle(.downPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)
    #expect(switcher.state.selectedWindowTitle == "B")

    switcher.handle(.downPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "C")
}

@Test func upAtWindowLevelSelectsThePreviousWindow() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("A"), .window("B"), .window("C")]))
    switcher.handle(.downPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.upPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "B")
}

@Test func upOnTheFirstWindowReturnsToAppLevelOnTheSameApp() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("A"), .window("B")]))
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.upPressed, desktop: desktop)

    #expect(switcher.state.isAtAppLevel)
    #expect(switcher.state.selectedName == "Safari")
}

@Test func upAtAppLevelDoesNothing() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("A"), .window("B")]))
    let before = switcher.state

    switcher.handle(.upPressed, desktop: desktop)

    #expect(switcher.state == before)
}

@Test func downOnTheFrontmostAppSelectsItsSecondWindowTheFirstBeingTheOneLeft() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"),
    ])
    var switcher = opened(on: desktop)
    switcher.handle(.shiftAppShortcutPressed, desktop: desktop)

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test(arguments: [SwitcherEvent.modifierReleased, .enterPressed])
func confirmingAtWindowLevelBringsOnlyTheSelectedWindowToTheFront(confirm: SwitcherEvent) throws {
    let chosen = DesktopWindow.window("B")
    let app = DesktopApp.regular("Safari", windows: [.window("A"), chosen])
    var (switcher, desktop) = openedOn(app)
    switcher.handle(.downPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    let effect = switcher.handle(confirm, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .bringWindowToFront(try #require(chosen.id), of: app.id))
}

@Test(arguments: [0, 1])
func downOnAnAppWithFewerThanTwoWindowsDoesNothing(windowCount: Int) {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: (0..<windowCount).map { _ in .window() }))
    let before = switcher.state

    switcher.handle(.downPressed, desktop: desktop)

    #expect(switcher.state == before)
}
