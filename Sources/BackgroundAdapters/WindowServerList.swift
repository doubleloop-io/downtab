import CoreGraphics
import Foundation

/// Level 0 holds apps' normal windows: menus, panels and the Dock sit on other levels.
enum WindowServerList {
    struct Window {
        let id: CGWindowID
        let ownerPID: pid_t
        let bounds: CGRect
    }

    /// Front to back. Off-screen windows include those of other Spaces and minimized ones.
    static func normalWindows(includingOffScreen: Bool) -> [Window] {
        let visibility: CGWindowListOption = includingOffScreen ? .optionAll : .optionOnScreenOnly
        let options: CGWindowListOption = [visibility, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t
            else { return nil }
            let bounds =
                (info[kCGWindowBounds as String] as? NSDictionary)
                .flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero
            return Window(id: id, ownerPID: pid, bounds: bounds)
        }
    }
}
