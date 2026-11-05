import AppKit
import BackgroundAdapters
import SwitcherCore
import os

/// Keeps an in-memory copy of the running apps, their MRU order and their windows, updated from NSWorkspace
/// notifications, Accessibility window events and background scans, so taking a snapshot when the Switcher opens
/// never queries other processes.
/// Translation only: which apps appear is decided by the core.
final class DesktopTracker {
    private struct TrackedApp {
        let process: NSRunningApplication
        /// Read once: `localizedName` can query LaunchServices, which opening must not wait for.
        let name: String
    }

    private var apps: [AppID: TrackedApp] = [:]
    private var mruOrder = MRUOrder(running: [], windowOwnersFrontToBack: [], frontmost: nil)
    private var observers: [any NSObjectProtocol] = []
    private let scanner = WindowScanner()
    private var scan: WindowScan?
    private var isScanning = false
    private var needsAnotherScan = false
    private var periodicScan: Task<Void, Never>?
    private var windowEvents: WindowEventObserver?
    private let logger = Logger(subsystem: "io.github.iacoware.downtab", category: "scan")

    func start() {
        let windowEvents = WindowEventObserver { [weak self] in self?.requestScan() }
        windowEvents.start()
        self.windowEvents = windowEvents
        let workspace = NSWorkspace.shared
        for app in workspace.runningApplications {
            track(app)
        }
        mruOrder = MRUOrder(
            running: workspace.runningApplications.map(AppID.init),
            windowOwnersFrontToBack: OnScreenWindowOrder.ownersFrontToBack(),
            frontmost: workspace.frontmostApplication.map(AppID.init)
        )
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
        // Fallback: Accessibility misses some events, and a window moved to another Space raises none.
        periodicScan = Task { [weak self] in
            while !Task.isCancelled {
                self?.requestScan()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// `freshWindowOrder` reorders the scanned windows by the window server's current front-to-back order: a
    /// window switch inside an app raises no event, so the last scan may still list the previous front window
    /// first (issue #29). Only the order is fresh; everything else about the windows comes from the scan.
    func snapshot(freshWindowOrder: Bool) -> DesktopSnapshot {
        let ranks = freshWindowOrder ? measuredWindowRanks() : nil
        let desktopApps = mruOrder.apps.compactMap { id in
            apps[id].map { app in
                let scanned = scan?.windowsByApp[id] ?? []
                return DesktopApp(
                    id: id, name: app.name, isRegular: app.process.activationPolicy == .regular,
                    isHidden: app.process.isHidden,
                    windows: ranks.map { scanned.orderedFrontToBack(onScreenRanks: $0) } ?? scanned)
            }
        }
        return DesktopSnapshot(
            apps: desktopApps,
            mruOrder: mruOrder.apps,
            currentSpaces: scan?.currentSpaces ?? [],
            isActiveSpaceFullScreen: scan?.isActiveSpaceFullScreen ?? false,
            frontmostApp: NSWorkspace.shared.frontmostApplication.map(AppID.init)
        )
    }

    private func measuredWindowRanks() -> [WindowID: Int] {
        let began = ContinuousClock.now
        let ranks = OnScreenWindowOrder.windowRanks()
        logger.debug(
            "window order windows=\(ranks.count) took=\(ContinuousClock.now - began, privacy: .public)")
        return ranks
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
        let regularApps = mruOrder.apps.filter { apps[$0]?.process.activationPolicy == .regular }
        // Here rather than at launch: an app can become regular after launching, or stop being regular.
        windowEvents?.watch(only: Set(regularApps))
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
        mruOrder.recordLaunch(of: id)
        requestScan()
    }

    private func recordActivation(of app: NSRunningApplication) {
        track(app)
        mruOrder.recordActivation(of: AppID(app))
        requestScan()
    }

    private func forget(_ app: NSRunningApplication) {
        let id = AppID(app)
        apps[id] = nil
        mruOrder.recordQuit(of: id)
    }
}

extension AppID {
    fileprivate init(_ app: NSRunningApplication) {
        self.init(processIdentifier: app.processIdentifier)
    }
}
