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
        case .activateApp(let id):
            activate(id)
        case .bringWindowToFront(let window, of: let app):
            await bringToFront(window, of: app, focusChange: latestFocusChange)
        }
    }

    private func activate(_ id: AppID) {
        guard let app = NSRunningApplication(processIdentifier: id.processIdentifier) else {
            logger.error("activate pid=\(id.processIdentifier): app no longer running")
            return
        }
        // Like the native switcher: the whole app comes forward, unhidden if needed.
        let activated = app.activate()
        logger.info("activate pid=\(id.processIdentifier) ok=\(activated)")
    }

    /// The spike's recipe (`docs/spike-results.md`, "Ricetta: alzare una finestra").
    private func bringToFront(_ windowID: WindowID, of app: AppID, focusChange: Int) async {
        let pid = app.processIdentifier
        let wid = windowID.rawValue
        guard let window = Self.element(of: windowID, in: app) else {
            logger.error("raise pid=\(pid) wid=\(wid): window gone, activating the app")
            activate(app)
            return
        }
        if AXAttribute.bool(of: window, kAXMinimizedAttribute) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
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
        if Self.frontmostWindowID() != wid {
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

    /// The topmost normal window on screen, whatever its app.
    private static func frontmostWindowID() -> CGWindowID? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        let front = list.first { $0[kCGWindowLayer as String] as? Int == 0 }
        return front?[kCGWindowNumber as String] as? CGWindowID
    }
}
