public enum ShortcutRejection: Equatable, Sendable {
    case noModifier
    /// ⇧ is kept free for moving the selection back.
    case containsShift
    case sameAsOther
    /// A known system shortcut, or one whose registration failed.
    case usedBySystem
    /// The shortcut registered, but not with ⇧, which moves the selection back.
    case shiftVariantUsedBySystem

    /// Shown in the Preferences under the recorder field.
    public var message: String {
        switch self {
        case .noModifier: "Add a modifier: ⌘, ⌥ or ⌃."
        case .containsShift: "⇧ is reserved for going back: record the shortcut without it."
        case .sameAsOther: "The other shortcut already uses this combination."
        case .usedBySystem: "macOS already uses this combination: choose another one."
        case .shiftVariantUsedBySystem: "macOS already uses this combination with ⇧: choose another one."
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

    /// Judges a shortcut by the combinations macOS refused to register: the shortcut and its ⇧ variant.
    public static func checkRegistration(of shortcut: Shortcut, refused: Set<Shortcut>) -> ShortcutOutcome {
        if refused.contains(shortcut) { return .rejected(.usedBySystem) }
        if refused.contains(shortcut.withShift) { return .rejected(.shiftVariantUsedBySystem) }
        return .valid
    }
}

extension Shortcuts {
    /// The slots whose shortcut does not open the Switcher, given the combinations macOS refused to register.
    public func registrationFailures(refused: Set<Shortcut>) -> [ShortcutSlot: ShortcutRejection] {
        var failures: [ShortcutSlot: ShortcutRejection] = [:]
        for slot in ShortcutSlot.allCases {
            if case .rejected(let rejection) = ShortcutRules.checkRegistration(of: self[slot], refused: refused) {
                failures[slot] = rejection
            }
        }
        return failures
    }
}

extension ShortcutRules {
    /// The native shortcuts that would swallow Downtab's: only exactly ⌘Tab or ⌘`, and only for shortcuts that
    /// registered, so a refused shortcut never leaves the native one off.
    public static func nativeShortcutsToTurnOff(
        for shortcuts: Shortcuts,
        failures: [ShortcutSlot: ShortcutRejection]
    ) -> Set<NativeShortcut> {
        let registered = ShortcutSlot.allCases.filter { failures[$0] == nil }.map { shortcuts[$0] }
        return Set(NativeShortcut.allCases.filter { registered.contains($0.shortcut) })
    }
}
