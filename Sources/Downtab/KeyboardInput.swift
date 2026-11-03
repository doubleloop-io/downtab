import AppKit
import BackgroundAdapters
import Carbon
import SwitcherCore
import os

final class KeyboardInput {
    private static let shortcutSignature = OSType(0x4454_4142)  // "DTAB"

    private let onEvent: (SwitcherEvent) -> Void
    private let logger = Logger(subsystem: "local.downtab", category: "keyboard")
    private let modifierRelease = ModifierReleaseTap()
    private let hotKeyPresses = HotKeyPressHandler()
    /// The combinations held on the keyboard: each shortcut, plus ⇧ for the reverse. Indexed by Carbon hot key id.
    private var registrations: [Shortcut] = []
    /// The last shortcuts registered, whether or not macOS accepted them.
    private(set) var shortcuts = Shortcuts.defaults
    private var shortcutRefs: [EventHotKeyRef?] = []
    private var keyMonitor: Any?

    init(onEvent: @escaping (SwitcherEvent) -> Void) {
        self.onEvent = onEvent
    }

    /// Shortcuts open the Switcher once registered with `register(_:)`.
    func start() {
        hotKeyPresses.install { [weak self] id in self?.shortcutPressed(id: id) }
        modifierRelease.start { [weak self] held in self?.onEvent(.modifiersChanged(held: held)) }
        // A local monitor sees keys sent to any of Downtab's windows: the Preferences need theirs.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window is SwitcherPanel else { return event }
            onEvent(Self.panelEvent(for: event))
            return nil
        }
    }

    /// A shortcut key the Carbon hot keys do not hold reaches the Switcher here, such as ⌥` opened with ⌥Tab
    /// while the Window shortcut is ⌃`.
    private static func panelEvent(for event: NSEvent) -> SwitcherEvent {
        switch Int(event.keyCode) {
        case kVK_Escape: .escapePressed
        case kVK_Return, kVK_ANSI_KeypadEnter: .enterPressed
        case kVK_DownArrow: .downPressed
        case kVK_UpArrow: .upPressed
        case kVK_LeftArrow: .leftPressed
        case kVK_RightArrow: .rightPressed
        case let keyCode:
            .keyPressed(Shortcut(keyCode: keyCode, modifiers: ShortcutModifier.held(in: event.modifierFlags)))
        }
    }

    private func shortcutPressed(id: UInt32) {
        guard registrations.indices.contains(Int(id)) else { return }
        onEvent(.keyPressed(registrations[Int(id)]))
        // The tap may report a quick release before Carbon delivers the press, while the Switcher was still closed.
        onEvent(.modifiersChanged(held: ModifierReleaseTap.heldModifiers))
    }

    /// Replaces the registered shortcuts, each with and without ⇧.
    /// Returns the combinations macOS refused, each shortcut with or without ⇧: another app or the system holds them.
    @discardableResult
    func register(_ shortcuts: Shortcuts) -> Set<Shortcut> {
        suspendShortcuts()
        self.shortcuts = shortcuts
        registrations = [shortcuts.app, shortcuts.app.withShift, shortcuts.window, shortcuts.window.withShift]
        var refused: Set<Shortcut> = []
        shortcutRefs = registrations.enumerated().map { index, combination in
            let name = ShortcutLabel.text(for: combination)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(combination.keyCode),
                Self.carbonModifiers(combination.modifiers),
                EventHotKeyID(signature: Self.shortcutSignature, id: UInt32(index)),
                GetEventDispatcherTarget(),
                0,
                &ref
            )
            if status == noErr {
                logger.info("shortcut \(name, privacy: .public) registered")
            } else {
                logger.error("shortcut \(name, privacy: .public) failed: \(status)")
                refused.insert(combination)
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
