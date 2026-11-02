import SwitcherCore

extension DesktopApp {
    static func regular(_ name: String, processIdentifier: Int32) -> DesktopApp {
        DesktopApp(id: AppID(processIdentifier: processIdentifier), name: name, isRegular: true)
    }
}

extension DesktopSnapshot {
    /// Regular apps named in most-recently-used order, each with its own process identity.
    /// The apps are listed in reverse, so the App row order can only come from the MRU order.
    static func with(mru names: [String]) -> DesktopSnapshot {
        let apps = names.enumerated().map { index, name in
            DesktopApp.regular(name, processIdentifier: Int32(index + 100))
        }
        return DesktopSnapshot(apps: apps.reversed(), mruOrder: apps.map(\.id))
    }
}

extension SwitcherState {
    var appRowNames: [String]? {
        guard case .open(let displayed) = self else { return nil }
        return displayed.appRow.map(\.name)
    }

    var selectedName: String? {
        guard case .open(let displayed) = self else { return nil }
        return displayed.selectedEntry.name
    }
}
