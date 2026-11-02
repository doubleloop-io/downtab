import AppKit
import SwitcherCore

/// Keeps an in-memory copy of the running apps and their MRU order, updated from NSWorkspace notifications,
/// so taking a snapshot when the Switcher opens never queries other processes.
/// Translation only: which apps appear is decided by the core.
final class DesktopTracker {
    private struct TrackedApp {
        let process: NSRunningApplication
        /// Read once: `localizedName` can query LaunchServices, which opening must not wait for.
        let name: String
    }

    private var apps: [AppID: TrackedApp] = [:]
    private var mruOrder: [AppID] = []
    private var observers: [any NSObjectProtocol] = []

    func start() {
        let workspace = NSWorkspace.shared
        for app in workspace.runningApplications {
            track(app)
        }
        // Until MRU seeding exists, only the frontmost app has a known position: first.
        if let frontmost = workspace.frontmostApplication {
            recordActivation(of: frontmost)
        }
        let center = workspace.notificationCenter
        observers = [
            observe(NSWorkspace.didLaunchApplicationNotification, on: center) { tracker, app in tracker.track(app) },
            observe(NSWorkspace.didActivateApplicationNotification, on: center) { tracker, app in
                tracker.recordActivation(of: app)
            },
            observe(NSWorkspace.didTerminateApplicationNotification, on: center) { tracker, app in
                tracker.forget(app)
            },
        ]
    }

    func snapshot() -> DesktopSnapshot {
        let desktopApps = mruOrder.compactMap { id in
            apps[id].map { app in
                DesktopApp(id: id, name: app.name, isRegular: app.process.activationPolicy == .regular)
            }
        }
        return DesktopSnapshot(apps: desktopApps, mruOrder: mruOrder)
    }

    func icon(for id: AppID) -> NSImage? {
        apps[id]?.process.icon
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        _ handle: @escaping @MainActor (DesktopTracker, NSRunningApplication) -> Void
    ) -> any NSObjectProtocol {
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                handle(self, app)
            }
        }
    }

    private func track(_ app: NSRunningApplication) {
        let id = AppID(app)
        guard apps[id] == nil else { return }
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? ""
        apps[id] = TrackedApp(process: app, name: name)
        mruOrder.append(id)
    }

    private func recordActivation(of app: NSRunningApplication) {
        track(app)
        let id = AppID(app)
        mruOrder.removeAll { $0 == id }
        mruOrder.insert(id, at: 0)
    }

    private func forget(_ app: NSRunningApplication) {
        let id = AppID(app)
        apps[id] = nil
        mruOrder.removeAll { $0 == id }
    }
}

extension AppID {
    fileprivate init(_ app: NSRunningApplication) {
        self.init(processIdentifier: app.processIdentifier)
    }
}
