/// Which apps the App row shows, and with which Window count badge.
extension DesktopSnapshot {
    func appRow() -> [AppRowEntry] {
        let appsByID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let regularApps = mruOrder.compactMap { appsByID[$0] }.filter(\.isRegular)
        // Like the native switcher, which shows every app from a full-screen app.
        let admitted = isFrontmostAppFullScreen(among: regularApps) ? regularApps : regularApps.filter(admits)
        return admitted.map { AppRowEntry(id: $0.id, name: $0.name, windowCountBadge: windowCountBadge(of: $0)) }
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

    /// Only an app with something to descend into gets a badge.
    private func windowCountBadge(of app: DesktopApp) -> Int? {
        let count = app.windows.count(where: isReachable)
        return count >= 2 ? count : nil
    }

    /// A window the Switcher can bring forward without leaving the Current Space, or a full-screen one.
    private func isReachable(_ window: DesktopWindow) -> Bool {
        window.role != nil && (window.spaces.isEmpty || window.isIn(currentSpaces) || window.isFullScreen)
    }
}

extension DesktopWindow {
    fileprivate func isIn(_ spaces: Set<SpaceID>) -> Bool {
        !self.spaces.isDisjoint(with: spaces)
    }

    /// Smaller windows are service windows (Zoom, iTerm2): their Space says nothing about where the app is.
    fileprivate var isLargeEnoughToBeReal: Bool {
        size.width >= 100 && size.height >= 50
    }
}
