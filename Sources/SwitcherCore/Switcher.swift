public enum SwitcherEvent: Equatable, Sendable {
    case appShortcutPressed
    /// ⇧ with the App shortcut key: moves the selection back.
    case shiftAppShortcutPressed
    case modifierReleased
    case enterPressed
    case escapePressed
    case downPressed
    case upPressed
}

/// What closing the Switcher asks the app to do.
public enum FinalEffect: Equatable, Sendable {
    /// Cancel: focus stays where it was.
    case noChange
    /// Confirm at App level: bring the app forward like the native switcher.
    case activateApp(AppID)
    /// Confirm at Window level: only that window comes forward, the app's other windows stay where they are.
    case bringWindowToFront(WindowID, of: AppID, restoring: WindowRestoration = [])
}

/// What must be undone before the window can come forward.
public struct WindowRestoration: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let unminimize = WindowRestoration(rawValue: 1 << 0)
    /// Unhides the whole app: hiding is per app, not per window.
    public static let unhide = WindowRestoration(rawValue: 1 << 1)
}

/// What confirming the window will do besides bringing it forward.
public enum WindowLabel: Equatable, Sendable {
    /// Restored from the Dock.
    case minimized
    /// Lives in a Space of its own: confirming moves there.
    case fullScreen
    /// Its app is hidden: confirming unhides the app.
    case hidden
}

public struct WindowListEntry: Equatable, Sendable {
    public let id: WindowID
    public let title: String
    public let labels: [WindowLabel]

    var restoration: WindowRestoration {
        var restoration: WindowRestoration = []
        if labels.contains(.minimized) { restoration.insert(.unminimize) }
        if labels.contains(.hidden) { restoration.insert(.unhide) }
        return restoration
    }
}

public struct AppRowEntry: Equatable, Sendable {
    public let id: AppID
    public let name: String
    /// Front to back.
    public let windows: [WindowListEntry]

    /// Nil when the app has fewer than 2 windows: only an app with something to descend into gets a badge.
    public var windowCountBadge: Int? { windows.count >= 2 ? windows.count : nil }
}

public enum SelectionLevel: Equatable, Sendable {
    case app
    /// The index of the selected window in the selected app's Window list.
    case window(Int)
}

public struct DisplayedState: Equatable, Sendable {
    public let appRow: [AppRowEntry]
    public private(set) var selectedIndex: Int
    public private(set) var level: SelectionLevel
    /// Fixed at opening, like the App row.
    let frontmostApp: AppID?

    init(appRow: [AppRowEntry], frontmostApp: AppID?) {
        self.appRow = appRow
        self.frontmostApp = frontmostApp
        selectedIndex = 0
        level = .app
    }

    public var selectedEntry: AppRowEntry { appRow[selectedIndex] }

    var confirmation: FinalEffect {
        switch level {
        case .app: .activateApp(selectedEntry.id)
        case .window(let index):
            .bringWindowToFront(
                selectedEntry.windows[index].id, of: selectedEntry.id,
                restoring: selectedEntry.windows[index].restoration)
        }
    }

    /// Wraps around at both ends of the App row, back at App level.
    func movingSelection(by step: Int) -> DisplayedState {
        let count = appRow.count
        var moved = self
        moved.selectedIndex = ((selectedIndex + step) % count + count) % count
        moved.level = .app
        return moved
    }

    /// `↓`: opens the Window list of an app with at least 2 windows, then walks it down to the last window.
    func movingDown() -> DisplayedState {
        switch level {
        case .app:
            guard selectedEntry.windowCountBadge != nil else { return self }
            // The Frontmost app's first window is the one being left.
            return at(.window(selectedEntry.id == frontmostApp ? 1 : 0))
        case .window(let index):
            return at(.window(min(index + 1, selectedEntry.windows.count - 1)))
        }
    }

    /// `↑`: walks the Window list up; from the first window, back to App level.
    func movingUp() -> DisplayedState {
        switch level {
        case .app: self
        case .window(0): at(.app)
        case .window(let index): at(.window(index - 1))
        }
    }

    private func at(_ level: SelectionLevel) -> DisplayedState {
        var moved = self
        moved.level = level
        return moved
    }
}

public enum SwitcherState: Equatable, Sendable {
    case closed
    case open(DisplayedState)
}

public struct Switcher: Sendable {
    public private(set) var state: SwitcherState = .closed

    public init() {}

    /// Returns the final effect when the event closes the Switcher, nil while it stays open or closed.
    @discardableResult
    public mutating func handle(_ event: SwitcherEvent, desktop: DesktopSnapshot) -> FinalEffect? {
        switch event {
        case .appShortcutPressed:
            moveSelection(by: 1, desktop: desktop)
            return nil
        case .shiftAppShortcutPressed:
            moveSelection(by: -1, desktop: desktop)
            return nil
        case .modifierReleased, .enterPressed:
            guard case .open(let displayed) = state else { return nil }
            state = .closed
            return displayed.confirmation
        case .escapePressed:
            guard state != .closed else { return nil }
            state = .closed
            return .noChange
        case .downPressed:
            if case .open(let displayed) = state { state = .open(displayed.movingDown()) }
            return nil
        case .upPressed:
            if case .open(let displayed) = state { state = .open(displayed.movingUp()) }
            return nil
        }
    }

    private mutating func moveSelection(by step: Int, desktop: DesktopSnapshot) {
        switch state {
        case .open(let displayed):
            state = .open(displayed.movingSelection(by: step))
        case .closed:
            // The App row is fixed at opening: it never moves while the Switcher is open.
            let appRow = desktop.appRow()
            guard !appRow.isEmpty else { return }
            // Opening starts on the app being left, so the first step lands on the previous app.
            let opening = DisplayedState(appRow: appRow, frontmostApp: desktop.frontmostApp)
            state = .open(opening.movingSelection(by: step))
        }
    }
}
