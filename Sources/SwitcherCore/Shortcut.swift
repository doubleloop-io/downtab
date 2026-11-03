public enum ShortcutModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case control, option, shift, command
}

/// A key plus modifiers, as the App shortcut or the Window shortcut.
public struct Shortcut: Hashable, Codable, Sendable {
    /// The macOS virtual key code: a key position, the same on every keyboard layout.
    public let keyCode: Int
    public let modifiers: Set<ShortcutModifier>

    public init(keyCode: Int, modifiers: Set<ShortcutModifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥Tab.
    public static let defaultApp = Shortcut(keyCode: 48, modifiers: [.option])
    /// ⌥`, the key left of `1`.
    public static let defaultWindow = Shortcut(keyCode: 50, modifiers: [.option])
}
