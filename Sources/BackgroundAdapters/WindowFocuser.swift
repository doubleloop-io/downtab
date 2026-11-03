import AppKit
import ApplicationServices
public import SwitcherCore
import os

/// Executes the final effect off the main thread, so a slow target app never stalls the Switcher.
/// An actor, so effects start in order.
public actor WindowFocuser {
    private let logger = Logger(subsystem: "local.downtab", category: "focus")
    /// Bumped by every focus change: a retry waiting across its sleep must not undo a newer one.
    private var latestFocusChange = 0

    public init() {}

    public func perform(_ effect: FinalEffect) async {
        if effect != .noChange { latestFocusChange += 1 }
        switch effect {
        case .noChange:
            break
        case .activateApp(let id, frontingWindow: let window):
            activate(id)
            if let window { front(window, of: id) }
        case .bringWindowToFront(let window, of: let app, let restoration):
            await bringToFront(window, of: app, restoring: restoration, focusChange: latestFocusChange)
        }
    }

    private func activate(_ id: AppID) {
        guard let app = NSRunningApplication(processIdentifier: id.processIdentifier) else {
            logger.error("activate pid=\(id.processIdentifier): app no longer running")
            return
        }
        logSpaces(beforeActivating: app)
        // Like the native switcher: the whole app comes forward, unhidden if needed.
        let activated = app.activate()
        logger.info("activate pid=\(id.processIdentifier) ok=\(activated)")
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            logSpaces(afterActivating: app)
        }
    }

    /// After activation, so the whole app still comes forward: the fronted window makes the window server move to
    /// its Space, which activation alone does not do from a full-screen Space for some apps (Miro).
    private func front(_ windowID: WindowID, of app: AppID) {
        let pid = app.processIdentifier
        let wid = windowID.rawValue
        let fronted = PrivateWindowFront.bringToFront(wid, of: pid)
        // Accessibility does not list windows of other Spaces: often there is nothing to raise.
        let raised = Self.element(of: windowID, in: app).map {
            AXUIElementPerformAction($0, kAXRaiseAction as CFString).rawValue
        }
        logger.info(
            "front after activate pid=\(pid) wid=\(wid) private=\(fronted) ax=\(raised.map(String.init) ?? "unlisted")")
    }

    /// Diagnosis aid: activation from a full-screen Space sometimes stays there (Miro), sometimes not (Slack).
    private func logSpaces(beforeActivating app: NSRunningApplication) {
        let pid = app.processIdentifier
        let spaces = PrivateSpaces.displaySpaces()
        let appSpaces = WindowServerList.normalWindows(includingOffScreen: true)
            .filter { $0.ownerPID == pid }
            .reduce(into: Set<UInt64>()) { $0.formUnion(PrivateSpaces.spaces(of: $1.id)) }
        let name = app.localizedName ?? "?"
        let inCurrent = !appSpaces.isDisjoint(with: spaces.current)
        logger.info(
            """
            activate pid=\(pid) name=\(name, privacy: .public) \
            windowsInCurrentSpace=\(inCurrent) appSpaces=\(Self.ids(appSpaces), privacy: .public) \
            \(Self.describe(spaces), privacy: .public)
            """)
    }

    private func logSpaces(afterActivating app: NSRunningApplication) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        logger.info(
            """
            after activate pid=\(app.processIdentifier) frontmost=\(frontmost) \
            \(Self.describe(PrivateSpaces.displaySpaces()), privacy: .public)
            """)
    }

    private static func describe(_ spaces: PrivateSpaces.DisplaySpaces) -> String {
        let active = spaces.active.map(String.init) ?? "?"
        let current = ids(spaces.current)
        return "current=\(current) active=\(active) activeFullScreen=\(spaces.isActiveFullScreen)"
    }

    private static func ids(_ spaces: Set<UInt64>) -> String {
        "[" + spaces.sorted().map(String.init).joined(separator: ",") + "]"
    }

    /// The spike's recipe (`docs/spike-results.md`, "Ricetta: alzare una finestra").
    private func bringToFront(
        _ windowID: WindowID, of app: AppID, restoring restoration: WindowRestoration, focusChange: Int
    ) async {
        let pid = app.processIdentifier
        let wid = windowID.rawValue
        guard let window = Self.element(of: windowID, in: app) else {
            logger.error("raise pid=\(pid) wid=\(wid): window gone, activating the app")
            activate(app)
            return
        }
        if restoration.contains(.unhide) {
            // Unhiding does not activate: the private front below still brings only this window forward.
            let unhidden = NSRunningApplication(processIdentifier: pid)?.unhide() ?? false
            logger.info("unhide pid=\(pid) ok=\(unhidden)")
        }
        if restoration.contains(.unminimize) {
            let restored = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            logger.info("unminimize pid=\(pid) wid=\(wid) ax=\(restored.rawValue)")
        }
        let fronted = PrivateWindowFront.bringToFront(wid, of: pid)
        if !fronted {
            // Degraded: the window still comes forward, but so do the app's other windows.
            activate(app)
        }
        let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        logger.info("raise pid=\(pid) wid=\(wid) private=\(fronted) ax=\(raised.rawValue)")
        // Some apps reorder their windows right after activation, pushing the raised one back.
        try? await Task.sleep(for: .milliseconds(150))
        guard focusChange == latestFocusChange else {
            logger.info("raise again skipped pid=\(pid) wid=\(wid): a newer focus change followed")
            return
        }
        if WindowServerList.normalWindows(includingOffScreen: false).first?.id != wid {
            let again = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            logger.info("raise again pid=\(pid) wid=\(wid) ax=\(again.rawValue)")
        }
    }

    private static func element(of windowID: WindowID, in app: AppID) -> AXUIElement? {
        let element = Accessibility.application(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else { return nil }
        return windows.first { PrivateSpaces.windowID(of: $0) == windowID.rawValue }
    }
}
