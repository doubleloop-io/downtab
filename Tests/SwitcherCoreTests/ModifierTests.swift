import SwitcherCore
import Testing

/// ⌥Tab and ⌃`: each shortcut opens with a Modifier the other one lacks.
private let mixed = Shortcuts(
    app: Shortcut(keyCode: KeyCode.tab, modifiers: [.option]),
    window: Shortcut(keyCode: KeyCode.grave, modifiers: [.control]))

/// Safari is the Frontmost app with two windows, Notes is behind it.
private let desktop = DesktopSnapshot.with(apps: [
    .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"),
])

private func openedWith(_ combination: Shortcut, shortcuts: Shortcuts = mixed) -> Switcher {
    var switcher = Switcher(shortcuts: shortcuts)
    switcher.handle(.keyPressed(combination), desktop: desktop)
    return switcher
}

@Test func releasingTheAppShortcutsModifierConfirms() {
    var switcher = openedWith(mixed.app)

    let effect = switcher.handle(.modifiersChanged(held: []), desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .activateApp(desktop.app(named: "Notes")))
}

@Test func releasingAnyKeyOfAMultiKeyModifierConfirms() {
    let shortcuts = Shortcuts(
        app: Shortcut(keyCode: KeyCode.tab, modifiers: [.option, .command]), window: mixed.window)
    var switcher = openedWith(shortcuts.app, shortcuts: shortcuts)

    let effect = switcher.handle(.modifiersChanged(held: [.option]), desktop: desktop)

    #expect(effect == .activateApp(desktop.app(named: "Notes")))
}

@Test func pressingAnotherModifierWhileOpenDoesNotConfirm() {
    var switcher = openedWith(mixed.app)

    let effect = switcher.handle(.modifiersChanged(held: [.option, .shift]), desktop: desktop)

    #expect(effect == nil)
    #expect(switcher.state.selectedName == "Notes")
}

@Test func windowShortcutKeyWithTheAppShortcutsModifierCyclesTheWindowList() {
    var switcher = openedWith(mixed.app)
    switcher.handle(.leftPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.keyPressed(Shortcut(keyCode: KeyCode.grave, modifiers: [.option])), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Current")
}

@Test func appShortcutKeyWithTheWindowShortcutsModifierAdvancesTheAppRow() {
    var switcher = openedWith(mixed.window)

    switcher.handle(.keyPressed(Shortcut(keyCode: KeyCode.tab, modifiers: [.control])), desktop: desktop)

    #expect(switcher.state.isAtAppLevel)
    #expect(switcher.state.selectedName == "Notes")
}

@Test func shiftWithTheModifierOnTheOtherShortcutsKeyGoesBack() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"), .regular("Mail"),
    ])
    var switcher = Switcher(shortcuts: mixed)
    switcher.handle(.keyPressed(mixed.window), desktop: desktop)

    switcher.handle(.keyPressed(Shortcut(keyCode: KeyCode.tab, modifiers: [.control, .shift])), desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
}

@Test(arguments: [
    Shortcut(keyCode: KeyCode.grave, modifiers: [.option, .control]),
    Shortcut(keyCode: KeyCode.grave, modifiers: [.control]),
])
func shortcutKeyWithoutExactlyTheOpeningModifierDoesNothing(combination: Shortcut) {
    var switcher = openedWith(mixed.app)
    switcher.handle(.leftPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.keyPressed(combination), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test func otherKeyWithTheModifierDoesNothingWhileOpen() {
    var switcher = openedWith(mixed.app)

    switcher.handle(.keyPressed(Shortcut(keyCode: KeyCode.space, modifiers: [.option])), desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test func shortcutKeyWithTheOtherShortcutsModifierDoesNotOpen() {
    var switcher = Switcher(shortcuts: mixed)

    switcher.handle(.keyPressed(Shortcut(keyCode: KeyCode.tab, modifiers: [.control])), desktop: desktop)

    #expect(switcher.state == .closed)
}

@Test func withBothShortcutsOnOneKeyTheOpeningShortcutKeepsItsMeaning() {
    let shortcuts = Shortcuts(
        app: Shortcut(keyCode: KeyCode.tab, modifiers: [.option]),
        window: Shortcut(keyCode: KeyCode.tab, modifiers: [.control]))
    var switcher = openedWith(shortcuts.window, shortcuts: shortcuts)

    switcher.handle(.keyPressed(shortcuts.window), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Current")
}
