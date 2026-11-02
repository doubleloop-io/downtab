public enum SwitcherEvent: Equatable, Sendable {
    case appShortcutPressed
    case escapePressed
}

/// What closing the Switcher asks the app to do.
public enum FinalEffect: Equatable, Sendable {
    /// Cancel: focus stays where it was.
    case noChange
}

public struct AppRowEntry: Equatable, Sendable {
    public let id: AppID
    public let name: String
}

public struct DisplayedState: Equatable, Sendable {
    public let appRow: [AppRowEntry]
    public let selectedIndex: Int

    public var selectedEntry: AppRowEntry { appRow[selectedIndex] }
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
            // The App row is fixed at opening: it never moves while the Switcher is open.
            guard state == .closed else { return nil }
            let appRow = Self.appRow(of: desktop)
            guard !appRow.isEmpty else { return nil }
            // The first app is the one being left, so the second is the likely target.
            state = .open(DisplayedState(appRow: appRow, selectedIndex: min(1, appRow.count - 1)))
            return nil
        case .escapePressed:
            guard state != .closed else { return nil }
            state = .closed
            return .noChange
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
