import AppKit
import Carbon
import SwitcherCore
import os

final class KeyboardInput {
    private let onEvent: (SwitcherEvent) -> Void
    private let logger = Logger(subsystem: "local.downtab", category: "keyboard")
    private var hotkeyHandler: EventHandlerRef?
    private var appShortcut: EventHotKeyRef?
    private var keyMonitor: Any?

    init(onEvent: @escaping (SwitcherEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        registerAppShortcut()
        // A local monitor only sees keys sent to Downtab's own windows, that is the key Switcher panel.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == UInt16(kVK_Escape) else { return event }
            onEvent(.escapePressed)
            return nil
        }
    }

    private func registerAppShortcut() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let input = Unmanaged<KeyboardInput>.fromOpaque(context).takeUnretainedValue()
                // Carbon dispatches hotkey events on the main run loop.
                MainActor.assumeIsolated { input.onEvent(.appShortcutPressed) }
                return noErr
            },
            1,
            &spec,
            context,
            &hotkeyHandler
        )
        let id = EventHotKeyID(signature: OSType(0x4454_4142), id: 1)  // "DTAB"
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(optionKey),
            id,
            GetEventDispatcherTarget(),
            0,
            &appShortcut
        )
        if installStatus == noErr, registerStatus == noErr {
            logger.info("app shortcut ⌥Tab registered")
        } else {
            logger.error("app shortcut ⌥Tab failed: handler=\(installStatus) hotkey=\(registerStatus)")
        }
    }
}
