import Carbon

enum HotkeyAction {
    case nextApp, previousApp, nextWindow, previousWindow, quit
}

/// ISO keyboards put the key above Tab on keycode 10 instead of 50, so both are registered.
private let bindings: [(keyCode: UInt32, modifiers: Int, action: HotkeyAction)] = [
    (UInt32(kVK_Tab), optionKey, .nextApp),
    (UInt32(kVK_Tab), optionKey | shiftKey, .previousApp),
    (UInt32(kVK_ANSI_Grave), optionKey, .nextWindow),
    (UInt32(kVK_ANSI_Grave), optionKey | shiftKey, .previousWindow),
    (UInt32(kVK_ISO_Section), optionKey, .nextWindow),
    (UInt32(kVK_ISO_Section), optionKey | shiftKey, .previousWindow),
    (UInt32(kVK_ANSI_Q), controlKey | optionKey | shiftKey, .quit),
]

private var onHotkey: ((HotkeyAction, UInt32, EventTime) -> Void)?

enum Hotkeys {
    static func register(_ handler: @escaping (HotkeyAction, _ keyCode: UInt32, _ pressedAt: EventTime) -> Void) {
        onHotkey = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let install = InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let binding = bindings[Int(id.id)]
            onHotkey?(binding.action, binding.keyCode, GetEventTime(event))
            return noErr
        }, 1, &spec, nil, nil)
        Log.write("carbon_handler status=\(install)")
        for (index, binding) in bindings.enumerated() {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x5350_4B45), id: UInt32(index))
            let status = RegisterEventHotKey(binding.keyCode, UInt32(binding.modifiers), id, GetEventDispatcherTarget(), 0, &reference)
            Log.write("hotkey_registered keycode=\(binding.keyCode) modifiers=\(binding.modifiers) action=\(binding.action) status=\(status)")
        }
    }
}
