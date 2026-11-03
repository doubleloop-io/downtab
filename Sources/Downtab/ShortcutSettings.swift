import BackgroundAdapters
import Carbon
import SwitcherCore

/// Applies shortcut changes from the Preferences: Shortcut rules first, then registration, then the Settings store.
final class ShortcutSettings {
    /// Combinations macOS keeps for itself. Shortcuts with ⇧ are left out: the Shortcut rules reject them anyway.
    /// Native ⌘Tab and ⌘` are left out: Downtab turns them off when it takes them over.
    private static let knownSystemShortcuts: Set<Shortcut> = [
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
    private let takeover: NativeShortcutTakeover
    private(set) var current: Shortcuts
    /// Current shortcuts macOS refused to register, with or without ⇧: they do not open the Switcher.
    private(set) var failures: [ShortcutSlot: ShortcutRejection] = [:]

    init(keyboard: KeyboardInput, takeover: NativeShortcutTakeover) {
        self.keyboard = keyboard
        self.takeover = takeover
        current = store.shortcuts()
    }

    /// A stored shortcut that fails to register stays stored: the Preferences show the failure.
    func registerStored() {
        registerCurrent()
    }

    /// Native ⌘Tab and ⌘` go off too: macOS would swallow them before the recorder sees them.
    func suspendWhileRecording() {
        keyboard.suspendShortcuts()
        takeover.turnOff(exactly: Set(NativeShortcut.allCases))
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
        let refused = keyboard.register(proposed)
        let registration = ShortcutRules.checkRegistration(of: recorded, refused: refused)
        guard registration == .valid else {
            registerCurrent()
            return registration
        }
        current = proposed
        failures = current.registrationFailures(refused: refused)
        takeOverNativeShortcuts()
        store.save(current)
        return .valid
    }

    /// Keeps the previous shortcuts when a default fails to register; returns the defaults' failures.
    func restoreDefaults() -> [ShortcutSlot: ShortcutRejection] {
        let defaultFailures = Shortcuts.defaults.registrationFailures(refused: keyboard.register(.defaults))
        guard defaultFailures.isEmpty else {
            registerCurrent()
            return defaultFailures
        }
        current = .defaults
        failures = [:]
        takeOverNativeShortcuts()
        store.save(current)
        return [:]
    }

    private func registerCurrent() {
        failures = current.registrationFailures(refused: keyboard.register(current))
        takeOverNativeShortcuts()
    }

    private func takeOverNativeShortcuts() {
        takeover.turnOff(exactly: ShortcutRules.nativeShortcutsToTurnOff(for: current, failures: failures))
    }
}
