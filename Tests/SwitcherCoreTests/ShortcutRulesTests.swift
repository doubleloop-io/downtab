import SwitcherCore
import Testing

/// macOS virtual key codes, the same on every layout.
private let tabKey = 48
private let graveKey = 50
private let spaceKey = 49

@Test func aShortcutWithoutAnyModifierIsRejected() {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: tabKey, modifiers: []),
        other: .defaultWindow,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.noModifier))
}

@Test(arguments: [
    Set<ShortcutModifier>([.option, .shift]),
    [.command, .control, .shift],
    [.shift],
])
func aShortcutContainingShiftIsRejected(modifiers: Set<ShortcutModifier>) {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: tabKey, modifiers: modifiers),
        other: .defaultWindow,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.containsShift))
}

@Test func aShortcutEqualToTheOtherShortcutIsRejected() {
    let other = Shortcut(keyCode: graveKey, modifiers: [.control])

    let outcome = ShortcutRules.check(
        Shortcut(keyCode: graveKey, modifiers: [.control]),
        other: other,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.sameAsOther))
}

@Test func aShortcutWithTheOtherShortcutsKeyButDifferentModifiersIsValid() {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: graveKey, modifiers: [.control]),
        other: Shortcut(keyCode: graveKey, modifiers: [.option]),
        systemShortcuts: []
    )

    #expect(outcome == .valid)
}

@Test func aShortcutUsedByTheSystemIsRejected() {
    let spotlight = Shortcut(keyCode: spaceKey, modifiers: [.command])

    let outcome = ShortcutRules.check(
        Shortcut(keyCode: spaceKey, modifiers: [.command]),
        other: .defaultWindow,
        systemShortcuts: [spotlight]
    )

    #expect(outcome == .rejected(.usedBySystem))
}

@Test func aShortcutWithASystemShortcutsKeyButDifferentModifiersIsValid() {
    let spotlight = Shortcut(keyCode: spaceKey, modifiers: [.command])

    let outcome = ShortcutRules.check(
        Shortcut(keyCode: spaceKey, modifiers: [.command, .option, .control]),
        other: .defaultWindow,
        systemShortcuts: [spotlight]
    )

    #expect(outcome == .valid)
}

@Test(arguments: [
    (Shortcut.defaultApp, Shortcut.defaultWindow),
    (Shortcut.defaultWindow, Shortcut.defaultApp),
    (Shortcut(keyCode: tabKey, modifiers: [.command, .option]), Shortcut.defaultWindow),
    (Shortcut(keyCode: graveKey, modifiers: [.control]), Shortcut.defaultApp),
])
func aShortcutWithAModifierAndNoConflictIsValid(recorded: Shortcut, other: Shortcut) {
    let outcome = ShortcutRules.check(recorded, other: other, systemShortcuts: [])

    #expect(outcome == .valid)
}

@Test(arguments: [
    (ShortcutRejection.noModifier, "Add a modifier: ⌘, ⌥ or ⌃."),
    (.containsShift, "⇧ is reserved for going back: record the shortcut without it."),
    (.sameAsOther, "The other shortcut already uses this combination."),
    (.usedBySystem, "macOS already uses this combination: choose another one."),
])
func everyRejectionHasAnEnglishMessage(rejection: ShortcutRejection, message: String) {
    #expect(rejection.message == message)
}
