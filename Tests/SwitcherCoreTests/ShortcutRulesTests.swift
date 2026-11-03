import SwitcherCore
import Testing

@Test func aShortcutWithoutAnyModifierIsRejected() {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.tab, modifiers: []),
        other: .defaultWindow,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.noModifier))
}

@Test func aShortcutWhoseOnlyModifierIsShiftIsRejectedForHavingNoModifier() {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.tab, modifiers: [.shift]),
        other: .defaultWindow,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.noModifier))
}

@Test(arguments: [
    Set<ShortcutModifier>([.option, .shift]),
    [.command, .control, .shift],
])
func aShortcutContainingShiftIsRejected(modifiers: Set<ShortcutModifier>) {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.tab, modifiers: modifiers),
        other: .defaultWindow,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.containsShift))
}

@Test func aShortcutEqualToTheOtherShortcutIsRejected() {
    let other = Shortcut(keyCode: KeyCode.grave, modifiers: [.control])

    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.grave, modifiers: [.control]),
        other: other,
        systemShortcuts: []
    )

    #expect(outcome == .rejected(.sameAsOther))
}

@Test func aShortcutWithTheOtherShortcutsKeyButDifferentModifiersIsValid() {
    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.grave, modifiers: [.control]),
        other: Shortcut(keyCode: KeyCode.grave, modifiers: [.option]),
        systemShortcuts: []
    )

    #expect(outcome == .valid)
}

@Test func aShortcutUsedByTheSystemIsRejected() {
    let spotlight = Shortcut(keyCode: KeyCode.space, modifiers: [.command])

    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.space, modifiers: [.command]),
        other: .defaultWindow,
        systemShortcuts: [spotlight]
    )

    #expect(outcome == .rejected(.usedBySystem))
}

@Test func aShortcutWithASystemShortcutsKeyButDifferentModifiersIsValid() {
    let spotlight = Shortcut(keyCode: KeyCode.space, modifiers: [.command])

    let outcome = ShortcutRules.check(
        Shortcut(keyCode: KeyCode.space, modifiers: [.command, .option, .control]),
        other: .defaultWindow,
        systemShortcuts: [spotlight]
    )

    #expect(outcome == .valid)
}

@Test(arguments: [
    (Shortcut.defaultApp, Shortcut.defaultWindow),
    (Shortcut.defaultWindow, Shortcut.defaultApp),
    (Shortcut(keyCode: KeyCode.tab, modifiers: [.command, .option]), Shortcut.defaultWindow),
    (Shortcut(keyCode: KeyCode.grave, modifiers: [.control]), Shortcut.defaultApp),
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
    (.shiftVariantUsedBySystem, "macOS already uses this combination with ⇧: choose another one."),
])
func everyRejectionHasAnEnglishMessage(rejection: ShortcutRejection, message: String) {
    #expect(rejection.message == message)
}

@Test func aShortcutMacOSRefusesOnlyWithShiftIsRejectedForItsShiftVariant() {
    let recorded = Shortcut(keyCode: KeyCode.space, modifiers: [.option])

    let outcome = ShortcutRules.checkRegistration(
        of: recorded,
        refused: [Shortcut(keyCode: KeyCode.space, modifiers: [.option, .shift])]
    )

    #expect(outcome == .rejected(.shiftVariantUsedBySystem))
}

@Test func aShortcutMacOSRefusesIsRejectedAsUsedBySystemEvenIfItsShiftVariantIsRefusedToo() {
    let recorded = Shortcut(keyCode: KeyCode.space, modifiers: [.option])

    let outcome = ShortcutRules.checkRegistration(of: recorded, refused: [recorded, recorded.withShift])

    #expect(outcome == .rejected(.usedBySystem))
}

@Test func aShortcutMacOSRegistersWithAndWithoutShiftIsValid() {
    let outcome = ShortcutRules.checkRegistration(
        of: Shortcut(keyCode: KeyCode.space, modifiers: [.option]),
        refused: [Shortcut(keyCode: KeyCode.tab, modifiers: [.option])]
    )

    #expect(outcome == .valid)
}
