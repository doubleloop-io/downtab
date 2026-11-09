public import SwitcherCore

/// Read from the window server alone: answers without asking any app, so a busy or frozen app never delays it.
public enum OnScreenWindowOrder {
    /// The owner of each level-0 window on screen, front to back: one entry per window, so owners repeat.
    public static func ownersFrontToBack() -> [AppID] {
        WindowServerList.normalWindows(includingOffScreen: false).map { AppID(processIdentifier: $0.ownerPID) }
    }

    /// Position of each level-0 window among on-screen ones, front to back. Only the on-screen list is front to
    /// back: the full one is in no useful order (issue #26). For on-screen windows that order is MRU, since focusing
    /// a window raises it.
    public static func windowRanks() -> [WindowID: Int] {
        let onScreen = WindowServerList.normalWindows(includingOffScreen: false).map { WindowID($0.id) }
        return Dictionary(zip(onScreen, onScreen.indices), uniquingKeysWith: { first, _ in first })
    }

    /// Level-0 windows on screen, front to back, with their bounds in window-server coordinates.
    public static func windowsFrontToBack() -> [OnScreenWindow] {
        WindowServerList.normalWindows(includingOffScreen: false).map { window in
            OnScreenWindow(
                owner: AppID(processIdentifier: window.ownerPID),
                bounds: ScreenRect(window.bounds),
                alpha: window.alpha)
        }
    }
}
