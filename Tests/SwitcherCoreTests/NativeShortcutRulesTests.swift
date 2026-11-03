import SwitcherCore
import Testing

private let commandTab = Shortcut(keyCode: KeyCode.tab, modifiers: [.command])
private let commandGrave = Shortcut(keyCode: KeyCode.grave, modifiers: [.command])

@Test func theDefaultShortcutsTurnNoNativeShortcutOff() {
    #expect(ShortcutRules.nativeShortcutsToTurnOff(for: .defaults).isEmpty)
}

@Test func commandTabAsAppShortcutTurnsNativeCommandTabOff() {
    let shortcuts = Shortcuts(app: commandTab, window: .defaultWindow)

    #expect(ShortcutRules.nativeShortcutsToTurnOff(for: shortcuts) == [.commandTab])
}

@Test func commandGraveAsWindowShortcutTurnsNativeCommandGraveOff() {
    let shortcuts = Shortcuts(app: .defaultApp, window: commandGrave)

    #expect(ShortcutRules.nativeShortcutsToTurnOff(for: shortcuts) == [.commandGrave])
}

@Test func aNativeShortcutIsTurnedOffWhicheverSlotHoldsIt() {
    let shortcuts = Shortcuts(app: commandGrave, window: commandTab)

    #expect(ShortcutRules.nativeShortcutsToTurnOff(for: shortcuts) == [.commandTab, .commandGrave])
}

@Test(arguments: [
    Shortcut(keyCode: KeyCode.tab, modifiers: [.command, .option]),
    Shortcut(keyCode: KeyCode.tab, modifiers: [.command, .control]),
    Shortcut(keyCode: KeyCode.grave, modifiers: [.command, .option]),
    Shortcut(keyCode: KeyCode.tab, modifiers: [.control]),
])
func onlyExactlyCommandTabOrCommandGraveTurnsANativeShortcutOff(shortcut: Shortcut) {
    let shortcuts = Shortcuts(app: shortcut, window: Shortcut(keyCode: KeyCode.space, modifiers: [.option]))

    #expect(ShortcutRules.nativeShortcutsToTurnOff(for: shortcuts).isEmpty)
}

@Test func aShortcutMacOSRefusedToRegisterTurnsNoNativeShortcutOff() {
    let shortcuts = Shortcuts(app: commandTab, window: commandGrave)

    let toTurnOff = ShortcutRules.nativeShortcutsToTurnOff(for: shortcuts, failures: [.app: .usedBySystem])

    #expect(toTurnOff == [.commandGrave])
}
