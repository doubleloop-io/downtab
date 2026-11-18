public import Foundation

/// When to remind the user, with a window, of a downloaded Update they have not installed. Downtab rarely quits, so
/// installing on quit may never happen: 7 days after the first signal, then every 7 days, a window asks once.
public struct UpdateReminder: Equatable, Sendable {
    public static let interval: TimeInterval = 7 * 24 * 60 * 60

    /// When the user was first told an Update is ready. Kept when a newer Update replaces the pending one: the user
    /// has been behind since then.
    public private(set) var firstSignalled: Date?
    public private(set) var lastReminded: Date?
    /// The build number (`CFBundleVersion`) of the Update last signalled.
    public private(set) var signalledBuild: Int?

    public init(firstSignalled: Date? = nil, lastReminded: Date? = nil, signalledBuild: Int? = nil) {
        self.firstSignalled = firstSignalled
        self.lastReminded = lastReminded
        self.signalledBuild = signalledBuild
    }

    /// At launch: running the signalled build, or a later one, means the Update was installed.
    public mutating func launched(runningBuild: Int) {
        guard let signalledBuild, runningBuild >= signalledBuild else { return }
        self = UpdateReminder()
    }

    public mutating func signalled(build: Int, at now: Date) {
        signalledBuild = build
        if firstSignalled == nil {
            firstSignalled = now
        }
    }

    public func isDue(at now: Date) -> Bool {
        guard let since = lastReminded ?? firstSignalled else { return false }
        return now.timeIntervalSince(since) >= Self.interval
    }

    public mutating func reminded(at now: Date) {
        lastReminded = now
    }
}
