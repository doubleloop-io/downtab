import SwitcherCore
import Testing

@Test func newSwitcherIsClosed() {
    let switcher = Switcher()

    #expect(switcher.state == .closed)
}

@Test func appShortcutOpensAppRowInMRUOrderWithSecondAppSelected() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.appRowNames == ["Mail", "Safari", "Notes"])
    #expect(switcher.state.selectedName == "Safari")
}

@Test func escapeCancelsLeavingFocusUnchanged() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari"])
    switcher.handle(.appShortcutPressed, desktop: desktop)

    let effect = switcher.handle(.escapePressed, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .noChange)
}

@Test func appRowKeepsItsOrderWhenMRUChangesWhileOpen() {
    var switcher = Switcher()
    switcher.handle(.appShortcutPressed, desktop: .with(mru: ["Mail", "Safari", "Notes"]))

    switcher.handle(.appShortcutPressed, desktop: .with(mru: ["Notes", "Mail", "Safari"]))

    #expect(switcher.state.appRowNames == ["Mail", "Safari", "Notes"])
}

@Test func appShortcutWithASingleAppSelectsIt() {
    var switcher = Switcher()

    switcher.handle(.appShortcutPressed, desktop: .with(mru: ["Finder"]))

    #expect(switcher.state.selectedName == "Finder")
}

@Test func appShortcutWithNoAppsLeavesTheSwitcherClosed() {
    var switcher = Switcher()

    switcher.handle(.appShortcutPressed, desktop: .with(mru: []))

    #expect(switcher.state == .closed)
}

@Test func escapeWhileClosedDoesNothing() {
    var switcher = Switcher()

    let effect = switcher.handle(.escapePressed, desktop: .with(mru: ["Mail"]))

    #expect(effect == nil)
}

@Test func appRowLeavesOutAppsThatAreNotRegular() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(apps: [.regular("Mail"), .agent("Menu bar agent"), .regular("Notes")])

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.appRowNames == ["Mail", "Notes"])
}

@Test func appShortcutPressedAgainAdvancesTheSelection() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    switcher.handle(.appShortcutPressed, desktop: desktop)

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test func appShortcutPastTheLastAppWrapsToTheFirst() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari"])
    switcher.handle(.appShortcutPressed, desktop: desktop)

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
}

@Test func shiftAppShortcutMovesTheSelectionBack() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    switcher.handle(.appShortcutPressed, desktop: desktop)
    switcher.handle(.appShortcutPressed, desktop: desktop)

    switcher.handle(.shiftAppShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
}

@Test func shiftAppShortcutBeforeTheFirstAppWrapsToTheLast() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    switcher.handle(.appShortcutPressed, desktop: desktop)
    switcher.handle(.shiftAppShortcutPressed, desktop: desktop)

    switcher.handle(.shiftAppShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test func shiftAppShortcutOpensTheSwitcherOnTheLeastRecentlyUsedApp() {
    var switcher = Switcher()

    switcher.handle(.shiftAppShortcutPressed, desktop: .with(mru: ["Mail", "Safari", "Notes"]))

    #expect(switcher.state.selectedName == "Notes")
}

@Test func modifierReleasedConfirmsByActivatingTheSelectedApp() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    switcher.handle(.appShortcutPressed, desktop: desktop)
    switcher.handle(.appShortcutPressed, desktop: desktop)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .activateApp(desktop.app(named: "Notes")))
}

@Test func enterConfirmsByActivatingTheSelectedApp() {
    var switcher = Switcher()
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari"])
    switcher.handle(.appShortcutPressed, desktop: desktop)

    let effect = switcher.handle(.enterPressed, desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .activateApp(desktop.app(named: "Safari")))
}

@Test func modifierReleasedWhileClosedDoesNothing() {
    var switcher = Switcher()

    let effect = switcher.handle(.modifierReleased, desktop: .with(mru: ["Mail", "Safari"]))

    #expect(effect == nil)
}
