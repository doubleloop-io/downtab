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
    /// Current shortcuts macOS refused to register, with or without ⇧: they do not open the Switcher.
    private(set) var failures: [ShortcutSlot: ShortcutRejection] = [:]
    /// Without the Accessibility permission the Switcher cannot detect the Modifier release, so the shortcuts stay
    /// off: a combination is registered only long enough to learn whether macOS accepts it.
    private var isEnabled = false

    init(keyboard: KeyboardInput) {
        self.keyboard = keyboard
        current = store.shortcuts()
    }

    /// A stored shortcut that fails to register stays stored: the Preferences show the failure.
    func enable() {
        isEnabled = true
        registerCurrent()
    }

    func disable() {
        isEnabled = false
        registerCurrent()
    }

    func suspendWhileRecording() {
        keyboard.suspendShortcuts()
    }

    func resumeAfterRecording() {
        registerCurrent()
    }

    func record(_ recorded: Shortcut, for slot: ShortcutSlot) -> ShortcutOutcome {
        let outcome = ShortcutRules.check(
            recorded, other: current[slot.other], systemShortcuts: Self.knownSystemShortcuts)
        guard outcome == .valid else { return outcome }
        var proposed = current
        proposed[slot] = recorded
        let refused = register(proposed)
        let registration = ShortcutRules.checkRegistration(of: recorded, refused: refused)
        guard registration == .valid else {
            registerCurrent()
            return registration
        }
        current = proposed
        failures = current.registrationFailures(refused: refused)
        store.save(current)
        return .valid
    }

    /// Keeps the previous shortcuts when a default fails to register; returns the defaults' failures.
    func restoreDefaults() -> [ShortcutSlot: ShortcutRejection] {
        let defaultFailures = Shortcuts.defaults.registrationFailures(refused: register(.defaults))
        guard defaultFailures.isEmpty else {
            registerCurrent()
            return defaultFailures
        }
        current = .defaults
        failures = [:]
        store.save(current)
        return [:]
    }

    private func registerCurrent() {
        failures = current.registrationFailures(refused: register(current))
    }

    private func register(_ shortcuts: Shortcuts) -> Set<Shortcut> {
        let refused = keyboard.register(shortcuts)
        if !isEnabled { keyboard.suspendShortcuts() }
        return refused
    }
}
