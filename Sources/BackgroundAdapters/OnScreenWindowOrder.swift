public import SwitcherCore

public enum OnScreenWindowOrder {
    /// The owner of each level-0 window on screen, front to back: one entry per window, so owners repeat.
    public static func ownersFrontToBack() -> [AppID] {
        WindowServerList.normalWindows(includingOffScreen: false).map { AppID(processIdentifier: $0.ownerPID) }
    }
}
