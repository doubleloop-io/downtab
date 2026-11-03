import SwitcherCore
import Testing

private func shortcut(_ keyCode: Int, _ modifiers: Set<ShortcutModifier>) -> Shortcut {
    Shortcut(keyCode: keyCode, modifiers: modifiers)
}

/// The default shortcuts, overriding only those the scenario is about.
private func shortcuts(app: Shortcut = .defaultApp, window: Shortcut = .defaultWindow) -> Shortcuts {
    Shortcuts(app: app, window: window)
}

private func opened(
    with combination: Shortcut, shortcuts: Shortcuts, on desktop: DesktopSnapshot
) -> Switcher {
    var switcher = Switcher(shortcuts: shortcuts)
    switcher.handle(.keyPressed(combination), desktop: desktop)
    return switcher
}

@Test func releasingTheAppShortcutsModifierConfirms() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari"), .regular("Notes")])
    let app = shortcut(KeyCode.tab, [.option])
    var switcher = opened(with: app, shortcuts: shortcuts(app: app), on: desktop)

    let effect = switcher.handle(.modifiersChanged(held: []), desktop: desktop)

    #expect(switcher.state == .closed)
    #expect(effect == .activateApp(desktop.app(named: "Notes")))
}

@Test func releasingAnyKeyOfAMultiKeyModifierConfirms() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari"), .regular("Notes")])
    let app = shortcut(KeyCode.tab, [.option, .command])
    var switcher = opened(with: app, shortcuts: shortcuts(app: app), on: desktop)

    let effect = switcher.handle(.modifiersChanged(held: [.option]), desktop: desktop)

    #expect(effect == .activateApp(desktop.app(named: "Notes")))
}

@Test func pressingAnotherModifierWhileOpenDoesNotConfirm() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari"), .regular("Notes")])
    let app = shortcut(KeyCode.tab, [.option])
    var switcher = opened(with: app, shortcuts: shortcuts(app: app), on: desktop)

    let effect = switcher.handle(.modifiersChanged(held: [.option, .shift]), desktop: desktop)

    #expect(effect == nil)
    #expect(switcher.state.selectedName == "Notes")
}

@Test func windowShortcutKeyWithTheAppShortcutsModifierCyclesTheWindowList() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"),
    ])
    let app = shortcut(KeyCode.tab, [.option])
    let window = shortcut(KeyCode.grave, [.control])
    var switcher = opened(with: app, shortcuts: shortcuts(app: app, window: window), on: desktop)
    switcher.handle(.leftPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.keyPressed(shortcut(KeyCode.grave, [.option])), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Current")
}

@Test func appShortcutKeyWithTheWindowShortcutsModifierAdvancesTheAppRow() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"),
    ])
    let app = shortcut(KeyCode.tab, [.option])
    let window = shortcut(KeyCode.grave, [.control])
    var switcher = opened(with: window, shortcuts: shortcuts(app: app, window: window), on: desktop)

    switcher.handle(.keyPressed(shortcut(KeyCode.tab, [.control])), desktop: desktop)

    #expect(switcher.state.isAtAppLevel)
    #expect(switcher.state.selectedName == "Notes")
}

@Test func shiftWithTheModifierOnTheOtherShortcutsKeyGoesBack() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"), .regular("Mail"),
    ])
    let app = shortcut(KeyCode.tab, [.option])
    let window = shortcut(KeyCode.grave, [.control])
    var switcher = opened(with: window, shortcuts: shortcuts(app: app, window: window), on: desktop)

    switcher.handle(.keyPressed(shortcut(KeyCode.tab, [.control, .shift])), desktop: desktop)

    #expect(switcher.state.selectedName == "Mail")
}

@Test(arguments: [
    Shortcut(keyCode: KeyCode.grave, modifiers: [.option, .control]),
    Shortcut(keyCode: KeyCode.grave, modifiers: [.control]),
])
func shortcutKeyWithoutExactlyTheOpeningModifierDoesNothing(combination: Shortcut) {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"),
    ])
    let app = shortcut(KeyCode.tab, [.option])
    let window = shortcut(KeyCode.grave, [.control])
    var switcher = opened(with: app, shortcuts: shortcuts(app: app, window: window), on: desktop)
    switcher.handle(.leftPressed, desktop: desktop)
    switcher.handle(.downPressed, desktop: desktop)

    switcher.handle(.keyPressed(combination), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test func otherKeyWithTheModifierDoesNothingWhileOpen() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari"), .regular("Notes")])
    let app = shortcut(KeyCode.tab, [.option])
    var switcher = opened(with: app, shortcuts: shortcuts(app: app), on: desktop)

    switcher.handle(.keyPressed(shortcut(KeyCode.space, [.option])), desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
}

@Test func shortcutKeyWithTheOtherShortcutsModifierDoesNotOpen() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari"), .regular("Notes")])
    var switcher = Switcher(
        shortcuts: shortcuts(app: shortcut(KeyCode.tab, [.option]), window: shortcut(KeyCode.grave, [.control])))

    switcher.handle(.keyPressed(shortcut(KeyCode.tab, [.control])), desktop: desktop)

    #expect(switcher.state == .closed)
}

@Test func withBothShortcutsOnOneKeyTheOpeningShortcutKeepsItsMeaning() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Safari", windows: [.window("Current"), .window("Behind")]), .regular("Notes"),
    ])
    let app = shortcut(KeyCode.tab, [.option])
    let window = shortcut(KeyCode.tab, [.control])
    var switcher = opened(with: window, shortcuts: shortcuts(app: app, window: window), on: desktop)

    switcher.handle(.keyPressed(window), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Current")
}
