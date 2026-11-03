import AppKit
import Carbon
import SwitcherCore

/// How each modifier is drawn, registered with Carbon and read from AppKit events.
/// `allCases` is in the order macOS draws modifiers: ⌃⌥⇧⌘.
extension ShortcutModifier {
    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    var carbonFlag: Int {
        switch self {
        case .control: controlKey
        case .option: optionKey
        case .shift: shiftKey
        case .command: cmdKey
        }
    }

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: .control
        case .option: .option
        case .shift: .shift
        case .command: .command
        }
    }

    static func held(in flags: NSEvent.ModifierFlags) -> Set<ShortcutModifier> {
        Set(allCases.filter { flags.contains($0.eventFlag) })
    }
}
