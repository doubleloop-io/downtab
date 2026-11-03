public import CoreGraphics
public import SwitcherCore

extension ShortcutModifier {
    public var eventFlag: CGEventFlags {
        switch self {
        case .control: .maskControl
        case .option: .maskAlternate
        case .shift: .maskShift
        case .command: .maskCommand
        }
    }

    public static func held(in flags: CGEventFlags) -> Set<ShortcutModifier> {
        Set(allCases.filter { flags.contains($0.eventFlag) })
    }
}
