public enum ShortcutRejection: Equatable, Sendable {
    case noModifier
    /// ⇧ is kept free for moving the selection back.
    case containsShift
    case sameAsOther
    /// A known system shortcut, or one whose registration failed.
    case usedBySystem

    /// Shown in the Preferences under the recorder field.
    public var message: String {
        switch self {
        case .noModifier: "Add a modifier: ⌘, ⌥ or ⌃."
        case .containsShift: "⇧ is reserved for going back: record the shortcut without it."
        case .sameAsOther: "The other shortcut already uses this combination."
        case .usedBySystem: "macOS already uses this combination: choose another one."
        }
    }
}

public enum ShortcutOutcome: Equatable, Sendable {
    case valid
    case rejected(ShortcutRejection)
}

/// Decides whether a shortcut being recorded can become the App shortcut or the Window shortcut.
public enum ShortcutRules {
    public static func check(
        _ recorded: Shortcut,
        other: Shortcut,
        systemShortcuts: Set<Shortcut>
    ) -> ShortcutOutcome {
        // ⇧ alone is no modifier: it only types capitals.
        if recorded.modifiers.subtracting([.shift]).isEmpty { return .rejected(.noModifier) }
        if recorded.modifiers.contains(.shift) { return .rejected(.containsShift) }
        if recorded == other { return .rejected(.sameAsOther) }
        if systemShortcuts.contains(recorded) { return .rejected(.usedBySystem) }
        return .valid
    }
}
