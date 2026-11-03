/// Process identity: each process is its own entry, so two instances of the same app stay distinct.
public struct AppID: Hashable, Sendable {
    public let processIdentifier: Int32

    public init(processIdentifier: Int32) {
        self.processIdentifier = processIdentifier
    }
}

public struct WindowID: Hashable, Sendable {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public struct SpaceID: Hashable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public struct WindowSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct DesktopWindow: Equatable, Sendable {
    /// Nil when the element is backed by no real window.
    public let id: WindowID?
    public let title: String
    /// Nil when only the window server knows the window: Accessibility does not list normal windows of other Spaces.
    public let role: String?
    public let subrole: String?
    /// Empty when unknown: some windows (Zoom, iTerm2) belong to no Space.
    public let spaces: Set<SpaceID>
    public let isMinimized: Bool
    public let isFullScreen: Bool
    /// Zero when the window server does not know the window.
    public let size: WindowSize

    public init(
        id: WindowID?,
        title: String,
        role: String?,
        subrole: String?,
        spaces: Set<SpaceID>,
        isMinimized: Bool,
        isFullScreen: Bool,
        size: WindowSize
    ) {
        self.id = id
        self.title = title
        self.role = role
        self.subrole = subrole
        self.spaces = spaces
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.size = size
    }
}

public struct DesktopApp: Equatable, Sendable {
    public let id: AppID
    public let name: String
    /// Has a Dock icon and a menu bar, as opposed to agents and background processes.
    public let isRegular: Bool
    /// Hidden with ⌘H.
    public let isHidden: Bool
    public let windows: [DesktopWindow]

    public init(id: AppID, name: String, isRegular: Bool, isHidden: Bool, windows: [DesktopWindow]) {
        self.id = id
        self.name = name
        self.isRegular = isRegular
        self.isHidden = isHidden
        self.windows = windows
    }
}

/// Raw facts about the desktop, with no Switcher rules applied.
public struct DesktopSnapshot: Equatable, Sendable {
    public let apps: [DesktopApp]
    /// Most recently used first.
    public let mruOrder: [AppID]
    /// The Space shown on each display.
    public let currentSpaces: Set<SpaceID>
    public let frontmostApp: AppID?

    public init(apps: [DesktopApp], mruOrder: [AppID], currentSpaces: Set<SpaceID>, frontmostApp: AppID?) {
        self.apps = apps
        self.mruOrder = mruOrder
        self.currentSpaces = currentSpaces
        self.frontmostApp = frontmostApp
    }
}
