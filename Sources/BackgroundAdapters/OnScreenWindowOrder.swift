import CoreGraphics
public import SwitcherCore

public enum OnScreenWindowOrder {
    /// The owner of each level-0 window on screen, front to back: one entry per window, so owners repeat.
    public static func ownersFrontToBack() -> [AppID] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                let pid = info[kCGWindowOwnerPID as String] as? Int32
            else { return nil }
            return AppID(processIdentifier: pid)
        }
    }
}
