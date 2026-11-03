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
    public static let defaultApp = Shortcut(keyCode: KeyCode.tab, modifiers: [.option])
    /// ⌥`.
    public static let defaultWindow = Shortcut(keyCode: KeyCode.grave, modifiers: [.option])
}

public enum ShortcutSlot: CaseIterable, Sendable {
    case app, window

    public var other: ShortcutSlot {
        switch self {
        case .app: .window
        case .window: .app
        }
    }

    /// The glossary name, shown in the Preferences.
    public var name: String {
        switch self {
        case .app: "App shortcut"
        case .window: "Window shortcut"
        }
    }
}

/// The App shortcut and the Window shortcut.
public struct Shortcuts: Equatable, Sendable {
    public var app: Shortcut
    public var window: Shortcut

    public init(app: Shortcut, window: Shortcut) {
        self.app = app
        self.window = window
    }

    public static let defaults = Shortcuts(app: .defaultApp, window: .defaultWindow)

    public subscript(slot: ShortcutSlot) -> Shortcut {
        get {
            switch slot {
            case .app: app
            case .window: window
            }
        }
        set {
            switch slot {
            case .app: app = newValue
            case .window: window = newValue
            }
        }
    }
}

/// macOS virtual key codes the core names: key positions, the same on every keyboard layout.
public enum KeyCode {
    public static let tab = 48
    public static let space = 49
    /// The key left of `1`: `` ` `` on US layouts.
    public static let grave = 50
}
