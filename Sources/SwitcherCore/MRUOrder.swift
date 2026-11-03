/// The running apps, most recently used first.
public struct MRUOrder: Equatable, Sendable {
    public private(set) var apps: [AppID]

    /// Downtab knows no history at launch: the on-screen window order is the best guess of recent use.
    public init(running: [AppID], windowOwnersFrontToBack: [AppID], frontmost: AppID?) {
        let isRunning = Set(running)
        var seeded: [AppID] = []
        for app in [frontmost].compactMap(\.self) + windowOwnersFrontToBack + running
        where isRunning.contains(app) && !seeded.contains(app) {
            seeded.append(app)
        }
        apps = seeded
    }

    public mutating func recordActivation(of app: AppID) {
        apps.removeAll { $0 == app }
        apps.insert(app, at: 0)
    }

    /// A launch is usually followed by its activation, which moves the app to the front.
    public mutating func recordLaunch(of app: AppID) {
        guard !apps.contains(app) else { return }
        apps.append(app)
    }

    public mutating func recordQuit(of app: AppID) {
        apps.removeAll { $0 == app }
    }
}
