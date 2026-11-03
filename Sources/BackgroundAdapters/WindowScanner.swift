import ApplicationServices
import CoreGraphics
import Foundation
public import SwitcherCore
import os

public struct WindowScan: Sendable {
    public let windowsByApp: [AppID: [DesktopWindow]]
    public let currentSpaces: Set<SpaceID>
}

/// Reads the windows of every app as raw facts, merging what Accessibility and the window server each know.
/// Opening the Switcher must never await a scan: it reads the copy the last scan left.
public actor WindowScanner {
    private let logger = Logger(subsystem: "local.downtab", category: "scan")
    private let query = TimeboxedQuery<AppID, [DesktopWindow]>()
    private var windowsByApp: [AppID: [DesktopWindow]] = [:]
    /// Twice the Accessibility timeout: a responsive app with many windows still answers in time.
    private static let appDeadline = Duration.milliseconds(500)

    public init() {}

    /// A frozen app keeps its last known windows and costs one deadline, not a stalled scan.
    public func scan(_ apps: [AppID]) async -> WindowScan {
        let began = ContinuousClock.now
        let spaces = PrivateSpaces.displaySpaces()
        let serverWindows = Self.serverWindowsByProcess()
        let result = await query.run(apps, within: Self.appDeadline) { app in
            Self.windows(of: app, serverWindows: serverWindows[app.processIdentifier] ?? [:], spaces: spaces)
        }
        log(result, previous: windowsByApp, took: ContinuousClock.now - began)
        windowsByApp = result.answers
        return WindowScan(windowsByApp: result.answers, currentSpaces: Set(spaces.current.map(SpaceID.init)))
    }

    /// Changes only at info level: a change logged with no window event just before it is a missed event.
    private func log(
        _ result: TimeboxedAnswers<AppID, [DesktopWindow]>, previous: [AppID: [DesktopWindow]], took: Duration
    ) {
        let changed = result.answers.keys.filter { result.answers[$0] != previous[$0] }
        if !result.unanswered.isEmpty {
            logger.info("scan no answer pid=\(Self.pids(result.unanswered), privacy: .public)")
        }
        if changed.isEmpty {
            logger.debug("scan apps=\(result.answers.count) took=\(took, privacy: .public)")
        } else {
            logger.info("scan changed pid=\(Self.pids(changed), privacy: .public) took=\(took, privacy: .public)")
        }
    }

    private static func pids(_ apps: some Collection<AppID>) -> String {
        apps.map { String($0.processIdentifier) }.sorted().joined(separator: ",")
    }

    private static func windows(
        of app: AppID,
        serverWindows: [CGWindowID: ServerWindow],
        spaces: PrivateSpaces.DisplaySpaces
    ) -> [DesktopWindow]? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, accessibilityTimeout)
        var listedWindows: CFTypeRef?
        let listing = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &listedWindows)
        // Timed out: the app is busy or frozen, so what it would answer is unknown, not "no windows".
        if listing == .cannotComplete { return nil }
        var listed: Set<CGWindowID> = []
        var windows: [DesktopWindow] = []
        for window in listedWindows as? [AXUIElement] ?? [] {
            let id = PrivateSpaces.windowID(of: window)
            if let id { listed.insert(id) }
            let windowSpaces = id.map(PrivateSpaces.spaces(of:)) ?? []
            windows.append(
                DesktopWindow(
                    id: id.map(WindowID.init),
                    title: AXAttribute.string(of: window, kAXTitleAttribute) ?? "",
                    role: AXAttribute.string(of: window, kAXRoleAttribute) ?? "",
                    subrole: AXAttribute.string(of: window, kAXSubroleAttribute),
                    spaces: Set(windowSpaces.map(SpaceID.init)),
                    isMinimized: AXAttribute.bool(of: window, kAXMinimizedAttribute),
                    isFullScreen: AXAttribute.bool(of: window, fullScreenAttribute)
                        || !windowSpaces.isDisjoint(with: spaces.fullScreen),
                    size: id.flatMap { serverWindows[$0]?.size } ?? WindowSize(width: 0, height: 0)
                ))
        }
        // Accessibility does not list normal windows of other Spaces: only the window server knows them.
        for (id, server) in serverWindows where !listed.contains(id) {
            let windowSpaces = PrivateSpaces.spaces(of: id)
            windows.append(
                DesktopWindow(
                    id: WindowID(id), title: "", role: nil, subrole: nil,
                    spaces: Set(windowSpaces.map(SpaceID.init)), isMinimized: false,
                    isFullScreen: !windowSpaces.isDisjoint(with: spaces.fullScreen), size: server.size
                ))
        }
        // The window server lists windows front to back; Accessibility's order is up to each app.
        return windows.sorted { lhs, rhs in
            depth(of: lhs, in: serverWindows) < depth(of: rhs, in: serverWindows)
        }
    }

    /// Windows the window server does not know go last.
    private static func depth(of window: DesktopWindow, in serverWindows: [CGWindowID: ServerWindow]) -> Int {
        window.id.flatMap { serverWindows[$0.rawValue]?.depth } ?? Int.max
    }

    private struct ServerWindow {
        let size: WindowSize
        /// Position in the window server's front-to-back order.
        let depth: Int
    }

    /// Level-0 windows of every Space, by owner process.
    private static func serverWindowsByProcess() -> [Int32: [CGWindowID: ServerWindow]] {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [:] }
        var result: [Int32: [CGWindowID: ServerWindow]] = [:]
        for (depth, info) in list.enumerated() {
            guard info[kCGWindowLayer as String] as? Int == 0,
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let pid = info[kCGWindowOwnerPID as String] as? Int32
            else { continue }
            let bounds =
                (info[kCGWindowBounds as String] as? NSDictionary)
                .flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero
            result[pid, default: [:]][id] = ServerWindow(
                size: WindowSize(width: bounds.width, height: bounds.height), depth: depth)
        }
        return result
    }

    private static let fullScreenAttribute = "AXFullScreen"
    private static let accessibilityTimeout: Float = 0.25
}

private enum AXAttribute {
    static func copy(of element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    static func string(of element: AXUIElement, _ attribute: String) -> String? {
        copy(of: element, attribute) as? String
    }

    static func bool(of element: AXUIElement, _ attribute: String) -> Bool {
        copy(of: element, attribute) as? Bool ?? false
    }
}
