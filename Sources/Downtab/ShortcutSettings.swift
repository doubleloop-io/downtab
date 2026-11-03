import Carbon
import SwitcherCore

/// Applies shortcut changes from the Preferences: Shortcut rules first, then registration, then the Settings store.
final class ShortcutSettings {
    /// Combinations macOS keeps for itself. Shortcuts with ⇧ are left out: the Shortcut rules reject them anyway.
    /// Native ⌘Tab and ⌘` stay here until Downtab can turn them off.
    private static let knownSystemShortcuts: Set<Shortcut> = [
        Shortcut(keyCode: kVK_Tab, modifiers: [.command]),
        Shortcut(keyCode: kVK_ANSI_Grave, modifiers: [.command]),
        Shortcut(keyCode: kVK_Space, modifiers: [.command]),
        Shortcut(keyCode: kVK_Space, modifiers: [.control]),
        Shortcut(keyCode: kVK_Space, modifiers: [.command, .option]),
        Shortcut(keyCode: kVK_Space, modifiers: [.command, .control]),
        Shortcut(keyCode: kVK_Escape, modifiers: [.command, .option]),
        Shortcut(keyCode: kVK_UpArrow, modifiers: [.control]),
        Shortcut(keyCode: kVK_DownArrow, modifiers: [.control]),
        Shortcut(keyCode: kVK_LeftArrow, modifiers: [.control]),
        Shortcut(keyCode: kVK_RightArrow, modifiers: [.control]),
        Shortcut(keyCode: kVK_ANSI_Q, modifiers: [.command, .control]),
    ]

    private let store = SettingsStore()
    private let keyboard: KeyboardInput
    private(set) var current: Shortcuts

    init(keyboard: KeyboardInput) {
        self.keyboard = keyboard
        current = store.shortcuts()
    }

    func suspendWhileRecording() {
        keyboard.suspendShortcuts()
    }

    func resumeAfterRecording() {
        keyboard.register(current)
    }

    func record(_ recorded: Shortcut, for slot: ShortcutSlot) -> ShortcutOutcome {
        let outcome = ShortcutRules.check(
            recorded, other: current[slot.other], systemShortcuts: Self.knownSystemShortcuts)
        guard outcome == .valid else { return outcome }
        var proposed = current
        proposed[slot] = recorded
        // A refused registration means another app or macOS holds the combination.
        guard !keyboard.register(proposed).contains(recorded) else {
            keyboard.register(current)
            return .rejected(.usedBySystem)
        }
        current = proposed
        store.save(current)
        return .valid
    }

    /// Returns the slots whose default macOS refused to register.
    func restoreDefaults() -> Set<ShortcutSlot> {
        current = .defaults
        store.save(current)
        let refused = keyboard.register(current)
        return Set(ShortcutSlot.allCases.filter { refused.contains(current[$0]) })
    }
}
