import AppKit
import BackgroundAdapters
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

    // AppKit's modifier flags are the Quartz event flags under another type: both come from the same IOKit masks.
    static func held(in flags: NSEvent.ModifierFlags) -> Set<ShortcutModifier> {
        held(in: CGEventFlags(rawValue: UInt64(flags.rawValue)))
    }
}
