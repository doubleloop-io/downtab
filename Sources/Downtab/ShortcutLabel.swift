import Carbon
import SwitcherCore

/// How a shortcut reads on screen and in logs, e.g. `⌥Tab`, with the key named by the current keyboard layout.
enum ShortcutLabel {
    /// Keys that type nothing visible.
    private static let keyNames: [Int: String] = [
        kVK_Tab: "Tab", kVK_Space: "Space", kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Escape: "Esc",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑",
        kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    static func text(for shortcut: Shortcut) -> String {
        modifiersText(shortcut.modifiers) + keyName(shortcut.keyCode)
    }

    static func modifiersText(_ modifiers: Set<ShortcutModifier>) -> String {
        ShortcutModifier.allCases.filter(modifiers.contains).map(\.symbol).joined()
    }

    private static func keyName(_ keyCode: Int) -> String {
        keyNames[keyCode] ?? typedCharacter(keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    /// The character the key types without modifiers on the current layout: `` ` `` on US, `\` on Italian.
    private static func typedCharacter(_ keyCode: Int) -> String? {
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        let typed = String(utf16CodeUnits: characters, count: length)
        return typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : typed
    }
}
