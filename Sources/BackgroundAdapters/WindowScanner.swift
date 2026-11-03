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
/// An actor so scans never overlap; it blocks on Accessibility, so opening the Switcher must never await it.
public actor WindowScanner {
    private let logger = Logger(subsystem: "local.downtab", category: "scan")

    public init() {}

    public func scan(_ apps: [AppID]) -> WindowScan {
        let began = ContinuousClock.now
        let spaces = PrivateSpaces.displaySpaces()
        let serverWindows = Self.serverWindowsByProcess()
        var windowsByApp: [AppID: [DesktopWindow]] = [:]
        for app in apps {
            windowsByApp[app] = Self.windows(
                of: app, serverWindows: serverWindows[app.processIdentifier] ?? [:], spaces: spaces)
        }
        logger.debug("scan apps=\(apps.count) took=\(ContinuousClock.now - began, privacy: .public)")
        return WindowScan(windowsByApp: windowsByApp, currentSpaces: Set(spaces.current.map(SpaceID.init)))
    }

    private static func windows(
        of app: AppID,
        serverWindows: [CGWindowID: WindowSize],
        spaces: PrivateSpaces.DisplaySpaces
    ) -> [DesktopWindow] {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        // A slow or frozen app must not stall the whole scan.
        AXUIElementSetMessagingTimeout(element, 0.25)
        var listed: Set<CGWindowID> = []
        var windows: [DesktopWindow] = []
        for window in AXAttribute.elements(of: element, kAXWindowsAttribute) {
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
                    size: id.flatMap { serverWindows[$0] } ?? WindowSize(width: 0, height: 0)
                ))
        }
        // Accessibility does not list normal windows of other Spaces: only the window server knows them.
        for (id, size) in serverWindows where !listed.contains(id) {
            let windowSpaces = PrivateSpaces.spaces(of: id)
            windows.append(
                DesktopWindow(
                    id: WindowID(id), title: "", role: nil, subrole: nil,
                    spaces: Set(windowSpaces.map(SpaceID.init)), isMinimized: false,
                    isFullScreen: !windowSpaces.isDisjoint(with: spaces.fullScreen), size: size
                ))
        }
        return windows
    }

    /// Level-0 windows of every Space, by owner process.
    private static func serverWindowsByProcess() -> [Int32: [CGWindowID: WindowSize]] {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [:] }
        var result: [Int32: [CGWindowID: WindowSize]] = [:]
        for info in list {
            guard info[kCGWindowLayer as String] as? Int == 0,
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let pid = info[kCGWindowOwnerPID as String] as? Int32
            else { continue }
            let bounds =
                (info[kCGWindowBounds as String] as? NSDictionary)
                .flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero
            result[pid, default: [:]][id] = WindowSize(width: bounds.width, height: bounds.height)
        }
        return result
    }

    private static let fullScreenAttribute = "AXFullScreen"
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

    static func elements(of element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        copy(of: element, attribute) as? [AXUIElement] ?? []
    }
}
