import SwitcherCore
import Synchronization

/// Distinct, deterministic process and window ids for builders.
private let nextID = Atomic<Int32>(1000)

private func uniqueID() -> Int32 {
    nextID.wrappingAdd(1, ordering: .relaxed).newValue
}

/// Spaces are written as plain numbers in tests.
private func spaceIDs(_ spaces: Set<UInt64>) -> Set<SpaceID> {
    Set(spaces.map(SpaceID.init))
}

extension DesktopWindow {
    /// A standard window listed by Accessibility, large enough to count as a real window.
    static func window(
        _ title: String = "Window",
        in spaces: Set<UInt64> = [],
        isMinimized: Bool = false,
        isFullScreen: Bool = false
    ) -> DesktopWindow {
        DesktopWindow(
            id: WindowID(UInt32(uniqueID())),
            title: title,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            spaces: spaceIDs(spaces),
            isMinimized: isMinimized,
            isFullScreen: isFullScreen,
            size: WindowSize(width: 800, height: 600)
        )
    }

    /// An element Accessibility lists as a window, by default in no known Space.
    static func listed(
        role: String,
        subrole: String?,
        title: String = "",
        hasID: Bool = true,
        in spaces: Set<UInt64> = [],
        isMinimized: Bool = false
    ) -> DesktopWindow {
        DesktopWindow(
            id: hasID ? WindowID(UInt32(uniqueID())) : nil,
            title: title,
            role: role,
            subrole: subrole,
            spaces: spaceIDs(spaces),
            isMinimized: isMinimized,
            isFullScreen: false,
            size: WindowSize(width: 800, height: 600)
        )
    }

    /// Known only to the window server, as normal windows of other Spaces are.
    static func unlisted(
        in spaces: Set<UInt64>,
        size: WindowSize = WindowSize(width: 800, height: 600),
        isFullScreen: Bool = false
    ) -> DesktopWindow {
        DesktopWindow(
            id: WindowID(UInt32(uniqueID())),
            title: "",
            role: nil,
            subrole: nil,
            spaces: spaceIDs(spaces),
            isMinimized: false,
            isFullScreen: isFullScreen,
            size: size
        )
    }
}

extension DesktopApp {
    static func regular(
        _ name: String,
        processIdentifier: Int32? = nil,
        isHidden: Bool = false,
        windows: [DesktopWindow] = []
    ) -> DesktopApp {
        DesktopApp(
            id: AppID(processIdentifier: processIdentifier ?? uniqueID()),
            name: name,
            isRegular: true,
            isHidden: isHidden,
            windows: windows
        )
    }
}

extension DesktopApp {
    /// A process with no Dock icon, such as a menu bar agent.
    static func agent(_ name: String) -> DesktopApp {
        DesktopApp(id: AppID(processIdentifier: uniqueID()), name: name, isRegular: false, isHidden: false, windows: [])
    }
}

extension DesktopSnapshot {
    /// Apps listed most recently used first; the first one is the Frontmost app.
    static func with(apps: [DesktopApp], currentSpaces: Set<UInt64> = [1]) -> DesktopSnapshot {
        DesktopSnapshot(
            apps: apps.reversed(),
            mruOrder: apps.map(\.id),
            currentSpaces: spaceIDs(currentSpaces),
            frontmostApp: apps.first?.id
        )
    }

    /// Regular apps with no windows named in most-recently-used order, each with its own process identity.
    /// The apps are listed in reverse, so the App row order can only come from the MRU order.
    static func with(mru names: [String]) -> DesktopSnapshot {
        with(
            apps: names.enumerated().map { index, name in
                DesktopApp.regular(name, processIdentifier: Int32(index + 100))
            }
        )
    }

    func app(named name: String) -> AppID {
        guard let app = apps.first(where: { $0.name == name }) else {
            preconditionFailure("no app named \(name) in the snapshot")
        }
        return app.id
    }
}

extension SwitcherState {
    var appRowNames: [String]? {
        guard case .open(let displayed) = self else { return nil }
        return displayed.appRow.map(\.name)
    }

    var appRowIDs: [AppID]? {
        guard case .open(let displayed) = self else { return nil }
        return displayed.appRow.map(\.id)
    }

    var selectedName: String? {
        guard case .open(let displayed) = self else { return nil }
        return displayed.selectedEntry.name
    }

    var windowListTitles: [String]? {
        guard case .open(let displayed) = self, case .window = displayed.level else { return nil }
        return displayed.selectedEntry.windows.map(\.title)
    }

    var selectedWindowTitle: String? {
        guard case .open(let displayed) = self, case .window(let index) = displayed.level else { return nil }
        return displayed.selectedEntry.windows[index].title
    }

    var isVisible: Bool {
        guard case .open(let displayed) = self else { return false }
        return displayed.isVisible
    }

    var isAtAppLevel: Bool {
        guard case .open(let displayed) = self else { return false }
        return displayed.level == .app
    }

    func windowCountBadge(of name: String) -> Int? {
        guard case .open(let displayed) = self, let entry = displayed.appRow.first(where: { $0.name == name }) else {
            preconditionFailure("no \(name) in an open App row")
        }
        return entry.windowCountBadge
    }
}

func opened(on desktop: DesktopSnapshot) -> Switcher {
    var switcher = Switcher()
    switcher.handle(.appShortcutPressed, desktop: desktop)
    return switcher
}

/// Another app is the Frontmost app, so the Switcher opens with the app under test selected.
func openedOn(_ app: DesktopApp) -> (Switcher, DesktopSnapshot) {
    let desktop = DesktopSnapshot.with(apps: [.regular("Frontmost"), app])
    return (opened(on: desktop), desktop)
}

/// Opens the Switcher on the snapshot and returns the names in its App row.
func appRowNames(of desktop: DesktopSnapshot) -> [String]? {
    opened(on: desktop).state.appRowNames
}
