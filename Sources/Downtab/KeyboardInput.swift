import AppKit
import BackgroundAdapters
import Carbon
import SwitcherCore
import os

final class KeyboardInput {
    private static let appShortcutSignature = OSType(0x4454_4142)  // "DTAB"
    /// Indexed by Carbon hot key id.
    private static let appShortcuts: [(name: String, modifiers: Int, event: SwitcherEvent)] = [
        ("⌥Tab", optionKey, .appShortcutPressed),
        ("⌥⇧Tab", optionKey | shiftKey, .shiftAppShortcutPressed),
    ]

    private let onEvent: (SwitcherEvent) -> Void
    private let logger = Logger(subsystem: "local.downtab", category: "keyboard")
    private let modifierRelease = ModifierReleaseTap()
    private var carbonHandler: EventHandlerRef?
    private var appShortcutRefs: [EventHotKeyRef?] = []
    private var keyMonitor: Any?

    init(onEvent: @escaping (SwitcherEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        registerAppShortcuts()
        modifierRelease.start { [weak self] in self?.onEvent(.modifierReleased) }
        // A local monitor only sees keys sent to Downtab's own windows, that is the key Switcher panel.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let switcherEvent = Self.panelEvent(forKeyCode: Int(event.keyCode)) else { return event }
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

    private func appShortcutPressed(id: UInt32) {
        guard Self.appShortcuts.indices.contains(Int(id)) else { return }
        onEvent(Self.appShortcuts[Int(id)].event)
        // The tap may report a quick release before Carbon delivers the press, while the Switcher was still closed.
        if !ModifierReleaseTap.isModifierDown {
            onEvent(.modifierReleased)
        }
    }

    private func registerAppShortcuts() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard status == noErr else { return status }
                let input = Unmanaged<KeyboardInput>.fromOpaque(context).takeUnretainedValue()
                // Carbon dispatches hot key events on the main run loop.
                MainActor.assumeIsolated { input.appShortcutPressed(id: id.id) }
                return noErr
            },
            1,
            &spec,
            context,
            &carbonHandler
        )
        if installStatus != noErr {
            logger.error("app shortcut handler failed: \(installStatus)")
        }
        appShortcutRefs = Self.appShortcuts.enumerated().map { index, shortcut in
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(kVK_Tab),
                UInt32(shortcut.modifiers),
                EventHotKeyID(signature: Self.appShortcutSignature, id: UInt32(index)),
                GetEventDispatcherTarget(),
                0,
                &ref
            )
            if status == noErr {
                logger.info("app shortcut \(shortcut.name, privacy: .public) registered")
            } else {
                logger.error("app shortcut \(shortcut.name, privacy: .public) failed: \(status)")
            }
            return ref
        }
    }
}
