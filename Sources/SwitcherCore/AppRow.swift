/// Which apps the App row shows, and which windows their Window list holds.
extension DesktopSnapshot {
    func appRow() -> [AppRowEntry] {
        let appsByID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let regularApps = mruOrder.compactMap { appsByID[$0] }.filter(\.isRegular)
        // Like the native switcher, which shows every app from a full-screen Space; App level only, for now.
        // The Space, not the Frontmost app: activation can bring an app forward and stay there.
        if isActiveSpaceFullScreen {
            return regularApps.map { entry(of: $0, windows: []) }
        }
        return regularApps.filter(admits).map { entry(of: $0, windows: windowList(of: $0)) }
    }

    private func entry(of app: DesktopApp, windows: [WindowListEntry]) -> AppRowEntry {
        AppRowEntry(
            id: app.id, name: app.name, windows: windows, windowToFrontOnActivation: windowInAnotherSpace(of: app))
    }

    /// The app's frontmost window, when all its windows are in other Spaces: from a full-screen Space, activation
    /// alone keeps macOS there for apps that do not bring a window forward themselves (Miro, Notion Calendar).
    private func windowInAnotherSpace(of app: DesktopApp) -> WindowID? {
        guard hasWindowsOnlyInOtherSpaces(app) else { return nil }
        let candidate = app.windows.first { window in
            // Accessibility does not list windows of other Spaces: an unlisted window counts by its size alone.
            !window.isMinimized && !window.spaces.isEmpty && window.isLargeEnoughToBeReal
                && (window.role == nil || window.isRealWindow)
        }
        return candidate?.id
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
        let reachable = app.windows.filter(isReachable)
        let minimizedLast = reachable.filter { !$0.isMinimized } + reachable.filter(\.isMinimized)
        return minimizedLast.compactMap { window in
            window.id.map {
                WindowListEntry(
                    id: $0, title: window.title.isEmpty ? "Untitled" : window.title,
                    labels: labels(of: window, in: app))
            }
        }
    }

    private func labels(of window: DesktopWindow, in app: DesktopApp) -> [WindowLabel] {
        [
            window.isMinimized ? .minimized : nil,
            app.isHidden ? .hidden : nil,
        ].compactMap(\.self)
    }

    /// A window the Switcher can bring forward without leaving the Current Space.
    private func isReachable(_ window: DesktopWindow) -> Bool {
        window.isRealWindow && (window.spaces.isEmpty || window.isIn(currentSpaces))
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
