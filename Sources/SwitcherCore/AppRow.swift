/// Which apps the App row shows, and which windows their Window list holds.
extension DesktopSnapshot {
    func appRow() -> [AppRowEntry] {
        let appsByID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let regularApps = mruOrder.compactMap { appsByID[$0] }.filter(\.isRegular)
        // Like the native switcher, which shows every app from a full-screen app.
        let admitted = isFrontmostAppFullScreen(among: regularApps) ? regularApps : regularApps.filter(admits)
        return admitted.map { AppRowEntry(id: $0.id, name: $0.name, windows: windowList(of: $0)) }
    }

    private func isFrontmostAppFullScreen(among apps: [DesktopApp]) -> Bool {
        guard let frontmost = apps.first(where: { $0.id == frontmostApp }) else { return false }
        return frontmost.windows.contains { $0.isFullScreen && $0.isIn(currentSpaces) }
    }

    private func admits(_ app: DesktopApp) -> Bool {
        // A full-screen window lives in a Space of its own: like the native switcher, activating it goes there.
        app.isHidden || app.windows.contains(where: \.isFullScreen) || !hasWindowsOnlyInOtherSpaces(app)
    }

    /// Activating such an app would change Space.
    private func hasWindowsOnlyInOtherSpaces(_ app: DesktopApp) -> Bool {
        // Without the Current Space (a private API gone), every window would look elsewhere.
        guard !currentSpaces.isEmpty else { return false }
        let placed = app.windows.filter { !$0.spaces.isEmpty && $0.isLargeEnoughToBeReal }
        return !placed.isEmpty && placed.allSatisfy { !$0.isIn(currentSpaces) }
    }

    private func windowList(of app: DesktopApp) -> [WindowListEntry] {
        app.windows.filter(isReachable).compactMap { window in
            window.id.map { WindowListEntry(id: $0, title: window.title) }
        }
    }

    /// A window the Switcher can bring forward without leaving the Current Space, or a full-screen one.
    private func isReachable(_ window: DesktopWindow) -> Bool {
        window.isRealWindow && (window.spaces.isEmpty || window.isIn(currentSpaces) || window.isFullScreen)
    }
}

extension DesktopWindow {
    /// Some apps list elements backed by no real window (cmux's `Item-0` dialogs) or that are not windows at all
    /// (Finder's desktop): public attributes alone cannot tell them apart, the window id can.
    fileprivate var isRealWindow: Bool {
        guard role == "AXWindow", id != nil else { return false }
        switch subrole {
        case "AXStandardWindow": return true
        case "AXDialog": return !title.isEmpty
        default: return false
        }
    }

    fileprivate func isIn(_ spaces: Set<SpaceID>) -> Bool {
        !self.spaces.isDisjoint(with: spaces)
    }

    /// Smaller windows are service windows (Zoom, iTerm2): their Space says nothing about where the app is.
    fileprivate var isLargeEnoughToBeReal: Bool {
        size.width >= 100 && size.height >= 50
    }
}
