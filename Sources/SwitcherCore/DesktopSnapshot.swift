/// Process identity: each process is its own entry, so two instances of the same app stay distinct.
public struct AppID: Hashable, Sendable {
    public let processIdentifier: Int32

    public init(processIdentifier: Int32) {
        self.processIdentifier = processIdentifier
    }
}

public struct DesktopApp: Equatable, Sendable {
    public let id: AppID
    public let name: String
    /// Has a Dock icon and a menu bar, as opposed to agents and background processes.
    public let isRegular: Bool

    public init(id: AppID, name: String, isRegular: Bool) {
        self.id = id
        self.name = name
        self.isRegular = isRegular
    }
}

/// Raw facts about the desktop, with no Switcher rules applied.
public struct DesktopSnapshot: Equatable, Sendable {
    public let apps: [DesktopApp]
    /// Most recently used first.
    public let mruOrder: [AppID]

    public init(apps: [DesktopApp], mruOrder: [AppID]) {
        self.apps = apps
        self.mruOrder = mruOrder
    }
}
