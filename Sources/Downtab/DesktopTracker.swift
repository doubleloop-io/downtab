import AppKit
import BackgroundAdapters
import SwitcherCore

/// Keeps an in-memory copy of the running apps, their MRU order and their windows, updated from NSWorkspace
/// notifications and background scans, so taking a snapshot when the Switcher opens never queries other processes.
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
    private let scanner = WindowScanner()
    private var scan: WindowScan?
    private var isScanning = false
    private var needsAnotherScan = false
    private var periodicScan: Task<Void, Never>?

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
            center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.requestScan() }
            },
        ]
        // Windows opened, closed or moved by hand raise no NSWorkspace notification.
        periodicScan = Task { [weak self] in
            while !Task.isCancelled {
                self?.requestScan()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func snapshot() -> DesktopSnapshot {
        let desktopApps = mruOrder.compactMap { id in
            apps[id].map { app in
                DesktopApp(
                    id: id, name: app.name, isRegular: app.process.activationPolicy == .regular,
                    isHidden: app.process.isHidden, windows: scan?.windowsByApp[id] ?? [])
            }
        }
        return DesktopSnapshot(
            apps: desktopApps,
            mruOrder: mruOrder,
            currentSpaces: scan?.currentSpaces ?? [],
            frontmostApp: NSWorkspace.shared.frontmostApplication.map(AppID.init)
        )
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

    /// Coalesces requests: at most one scan runs, and at most one more follows it.
    private func requestScan() {
        guard !isScanning else {
            needsAnotherScan = true
            return
        }
        isScanning = true
        // Agents never reach the App row: querying them would only slow the scan.
        let regularApps = mruOrder.filter { apps[$0]?.process.activationPolicy == .regular }
        Task { [weak self, scanner] in
            let result = await scanner.scan(regularApps)
            guard let self else { return }
            scan = result
            isScanning = false
            if needsAnotherScan {
                needsAnotherScan = false
                requestScan()
            }
        }
    }

    private func track(_ app: NSRunningApplication) {
        let id = AppID(app)
        guard apps[id] == nil else { return }
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? ""
        apps[id] = TrackedApp(process: app, name: name)
        mruOrder.append(id)
        requestScan()
    }

    private func recordActivation(of app: NSRunningApplication) {
        track(app)
        let id = AppID(app)
        mruOrder.removeAll { $0 == id }
        mruOrder.insert(id, at: 0)
        requestScan()
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
