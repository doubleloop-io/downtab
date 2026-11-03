import AppKit
import BackgroundAdapters
import Carbon
import SwitcherCore
import os

final class KeyboardInput {
    private struct Registration {
        /// What is held on the keyboard: the shortcut, plus ⇧ for the reverse registration.
        let combination: Shortcut
        let event: SwitcherEvent
    }

    private static let shortcutSignature = OSType(0x4454_4142)  // "DTAB"

    private let onEvent: (SwitcherEvent) -> Void
    private let logger = Logger(subsystem: "local.downtab", category: "keyboard")
    private let modifierRelease = ModifierReleaseTap()
    private let hotKeyPresses = HotKeyPressHandler()
    /// Indexed by Carbon hot key id.
    private var registrations: [Registration] = []
    private var shortcutRefs: [EventHotKeyRef?] = []
    private var keyMonitor: Any?

    init(onEvent: @escaping (SwitcherEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start(shortcuts: Shortcuts) {
        hotKeyPresses.install { [weak self] id in self?.shortcutPressed(id: id) }
        register(shortcuts)
        modifierRelease.start { [weak self] in self?.onEvent(.modifierReleased) }
        // A local monitor sees keys sent to any of Downtab's windows: the Preferences need theirs.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window is SwitcherPanel,
                let switcherEvent = Self.panelEvent(forKeyCode: Int(event.keyCode))
            else { return event }
            onEvent(switcherEvent)
            return nil
        }
    }

    private static func panelEvent(forKeyCode keyCode: Int) -> SwitcherEvent? {
        switch keyCode {
        case kVK_Escape: .escapePressed
        case kVK_Return, kVK_ANSI_KeypadEnter: .enterPressed
        case kVK_DownArrow: .downPressed
        case kVK_UpArrow: .upPressed
        case kVK_LeftArrow: .leftPressed
        case kVK_RightArrow: .rightPressed
        default: nil
        }
    }

    private func shortcutPressed(id: UInt32) {
        guard registrations.indices.contains(Int(id)) else { return }
        onEvent(registrations[Int(id)].event)
        // The tap may report a quick release before Carbon delivers the press, while the Switcher was still closed.
        if !ModifierReleaseTap.isModifierDown {
            onEvent(.modifierReleased)
        }
    }

    /// Replaces the registered shortcuts, each with and without ⇧.
    /// Returns the combinations macOS refused, each shortcut with or without ⇧: another app or the system holds them.
    @discardableResult
    func register(_ shortcuts: Shortcuts) -> Set<Shortcut> {
        suspendShortcuts()
        registrations = [
            Registration(combination: shortcuts.app, event: .appShortcutPressed),
            Registration(combination: shortcuts.app.withShift, event: .shiftAppShortcutPressed),
            Registration(combination: shortcuts.window, event: .windowShortcutPressed),
            Registration(combination: shortcuts.window.withShift, event: .shiftWindowShortcutPressed),
        ]
        var refused: Set<Shortcut> = []
        shortcutRefs = registrations.enumerated().map { index, registration in
            let name = ShortcutLabel.text(for: registration.combination)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(registration.combination.keyCode),
                Self.carbonModifiers(registration.combination.modifiers),
                EventHotKeyID(signature: Self.shortcutSignature, id: UInt32(index)),
                GetEventDispatcherTarget(),
                0,
                &ref
            )
            if status == noErr {
                logger.info("shortcut \(name, privacy: .public) registered")
            } else {
                logger.error("shortcut \(name, privacy: .public) failed: \(status)")
                refused.insert(registration.combination)
            }
            return ref
        }
        return refused
    }

    /// While a shortcut is being recorded, its keys must reach the recorder instead of opening the Switcher.
    func suspendShortcuts() {
        for ref in shortcutRefs.compactMap(\.self) {
            UnregisterEventHotKey(ref)
        }
        shortcutRefs = []
    }

    private static func carbonModifiers(_ modifiers: Set<ShortcutModifier>) -> UInt32 {
        UInt32(modifiers.reduce(0) { $0 | $1.carbonFlag })
    }
}
