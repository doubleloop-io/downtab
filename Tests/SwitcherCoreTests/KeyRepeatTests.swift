import SwitcherCore
import Testing

extension SwitcherEvent {
    fileprivate static let appShortcutRepeated = SwitcherEvent.keyRepeated(.defaultApp)
    fileprivate static let shiftAppShortcutRepeated = SwitcherEvent.keyRepeated(Shortcut.defaultApp.withShift)
    fileprivate static let windowShortcutRepeated = SwitcherEvent.keyRepeated(.defaultWindow)
    fileprivate static let shiftWindowShortcutRepeated = SwitcherEvent.keyRepeated(Shortcut.defaultWindow.withShift)
}

/// Safari is the Frontmost app, with the given windows front to back.
private func desktopWithFrontmostSafari(windows titles: [String]) -> DesktopSnapshot {
    DesktopSnapshot.with(apps: [.regular("Safari", windows: titles.map { .window($0) }), .regular("Notes")])
}

@Test func heldAppShortcutAdvancesTheSelection() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)

    switcher.handle(.appShortcutRepeated, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test func heldAppShortcutStopsOnTheLastApp() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)
    switcher.handle(.appShortcutRepeated, desktop: desktop)

    switcher.handle(.appShortcutRepeated, desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test func heldShiftAppShortcutStopsOnTheFirstApp() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)
    switcher.handle(.shiftAppShortcutRepeated, desktop: desktop)

    switcher.handle(.shiftAppShortcutRepeated, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
}

@Test func appShortcutPressedAfterStoppingOnTheLastAppStillWraps() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)
    switcher.handle(.appShortcutRepeated, desktop: desktop)
    switcher.handle(.appShortcutRepeated, desktop: desktop)

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
}

@Test func heldAppShortcutWhileClosedLeavesTheSwitcherClosed() {
    var switcher = Switcher()

    switcher.handle(.appShortcutRepeated, desktop: .with(mru: ["Mail", "Safari"]))

    #expect(switcher.state == .closed)
}

@Test func heldWindowShortcutStopsOnTheLastWindow() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)
    switcher.handle(.windowShortcutRepeated, desktop: desktop)

    switcher.handle(.windowShortcutRepeated, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Back")
}

@Test func heldShiftWindowShortcutStopsOnTheFirstWindow() {
    let desktop = desktopWithFrontmostSafari(windows: ["Current", "Behind", "Back"])
    var switcher = Switcher()
    switcher.handle(.windowShortcutPressed, desktop: desktop)
    switcher.handle(.shiftWindowShortcutRepeated, desktop: desktop)

    switcher.handle(.shiftWindowShortcutRepeated, desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Current")
}
