public enum SwitcherEvent: Equatable, Sendable {
    case appShortcutPressed
    /// ⇧ with the App shortcut key: moves the selection back.
    case shiftAppShortcutPressed
    case modifierReleased
    case enterPressed
    case escapePressed
}

/// What closing the Switcher asks the app to do.
public enum FinalEffect: Equatable, Sendable {
    /// Cancel: focus stays where it was.
    case noChange
    /// Confirm at App level: bring the app forward like the native switcher.
    case activateApp(AppID)
}

public struct AppRowEntry: Equatable, Sendable {
    public let id: AppID
    public let name: String
}

public struct DisplayedState: Equatable, Sendable {
    public let appRow: [AppRowEntry]
    public let selectedIndex: Int

    public var selectedEntry: AppRowEntry { appRow[selectedIndex] }

    /// Wraps around at both ends of the App row.
    func movingSelection(by step: Int) -> DisplayedState {
        let count = appRow.count
        return DisplayedState(appRow: appRow, selectedIndex: ((selectedIndex + step) % count + count) % count)
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
            return .activateApp(displayed.selectedEntry.id)
        case .escapePressed:
            guard state != .closed else { return nil }
            state = .closed
            return .noChange
        }
    }

    private mutating func moveSelection(by step: Int, desktop: DesktopSnapshot) {
        switch state {
        case .open(let displayed):
            state = .open(displayed.movingSelection(by: step))
        case .closed:
            // The App row is fixed at opening: it never moves while the Switcher is open.
            let appRow = Self.appRow(of: desktop)
            guard !appRow.isEmpty else { return }
            // Opening starts on the app being left, so the first step lands on the previous app.
            state = .open(DisplayedState(appRow: appRow, selectedIndex: 0).movingSelection(by: step))
        }
    }

    private static func appRow(of desktop: DesktopSnapshot) -> [AppRowEntry] {
        let appsByID = Dictionary(desktop.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Only regular apps appear, as in the native switcher.
        return desktop.mruOrder.compactMap { appsByID[$0] }.filter(\.isRegular).map {
            AppRowEntry(id: $0.id, name: $0.name)
        }
    }
}
