import AppKit
import ApplicationServices

struct WindowEntry {
    let element: AXUIElement
    let id: CGWindowID?
    let title: String
    let subrole: String
    let isMinimized: Bool
}

struct AppEntry {
    let pid: pid_t
    let name: String
    let windows: [WindowEntry]
    let rejected: [String]
    let hasWindowsOnlyInOtherSpaces: Bool
}

struct ServerWindow {
    let id: CGWindowID
    let pid: pid_t
    let isOnScreen: Bool
    let isLargeEnough: Bool
}

enum WindowServer {
    static func windows(onScreenOnly: Bool) -> [ServerWindow] {
        let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t else { return nil }
            let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero
            return ServerWindow(id: id, pid: pid, isOnScreen: info[kCGWindowIsOnscreen as String] as? Bool ?? false,
                                isLargeEnough: bounds.width >= 100 && bounds.height >= 50)
        }
    }
}

/// Keeps the list ready in memory: opening the panel must never wait on AX, where a slow app blocks for up to 1 s.
final class Inventory {
    private let lock = NSLock()
    private var cached: (apps: [AppEntry], at: Date) = ([], .distantPast)
    private let queue = DispatchQueue(label: "inventory")
    private var timer: DispatchSourceTimer?

    var snapshot: (apps: [AppEntry], at: Date) {
        lock.lock(); defer { lock.unlock() }
        return cached
    }

    func startRefreshing() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1)
        timer.setEventHandler { [weak self] in self?.refresh() }
        timer.resume()
        self.timer = timer
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.queue.async { self?.refresh() }
            }
        }
    }

    private func refresh() {
        let began = Date()
        let apps = Inventory.scan()
        lock.lock(); cached = (apps, Date()); lock.unlock()
        let elapsed = Date().timeIntervalSince(began) * 1000
        if elapsed > 200 { Log.write(String(format: "inventory_slow ms=%.0f apps=%d", elapsed, apps.count)) }
    }

    static func scan() -> [AppEntry] {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
        let allWindows = WindowServer.windows(onScreenOnly: false)
        let currentSpaces = PrivateAPI.currentSpaceIDs()
        let zOrder = WindowServer.windows(onScreenOnly: true).map(\.pid)
        var results = [AppEntry?](repeating: nil, count: running.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: running.count) { index in
            let entry = scan(running[index], allWindows: allWindows, currentSpaces: currentSpaces)
            lock.lock(); results[index] = entry; lock.unlock()
        }
        func rank(_ app: AppEntry) -> Int { zOrder.firstIndex(of: app.pid) ?? Int.max }
        return results.compactMap { $0 }.sorted { (rank($0), $0.name) < (rank($1), $1.name) }
    }

    private static func scan(_ app: NSRunningApplication, allWindows: [ServerWindow], currentSpaces: Set<UInt64>) -> AppEntry {
        let pid = app.processIdentifier
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        var windows: [WindowEntry] = []
        var rejected: [String] = []
        for window in AX.elements(element, kAXWindowsAttribute) {
            let entry = WindowEntry(element: window, id: PrivateAPI.windowID(of: window),
                                    title: AX.string(window, kAXTitleAttribute) ?? "",
                                    subrole: AX.string(window, kAXSubroleAttribute) ?? "",
                                    isMinimized: AX.bool(window, kAXMinimizedAttribute))
            let spaces = entry.id.map(PrivateAPI.spaces(of:)) ?? []
            if entry.isMinimized, !spaces.isEmpty, Set(spaces).isDisjoint(with: currentSpaces) {
                // Restoring it un-minimizes it back in its own Space: from here nothing visible would happen.
                rejected.append("minimized_other_space:\(entry.subrole):\(entry.title)")
            } else if let reason = rejectionReason(entry, role: AX.string(window, kAXRoleAttribute) ?? "") {
                rejected.append("\(reason):\(entry.subrole):\(entry.title)")
            } else {
                windows.append(entry)
            }
        }
        let spaces = allWindows.filter { $0.pid == pid && $0.isLargeEnough }.map { PrivateAPI.spaces(of: $0.id) }
        let isOnlyElsewhere = spaces.contains { !$0.isEmpty } && spaces.allSatisfy { Set($0).isDisjoint(with: currentSpaces) }
        return AppEntry(pid: pid, name: app.localizedName ?? "pid \(pid)", windows: windows, rejected: rejected,
                        hasWindowsOnlyInOtherSpaces: windows.isEmpty && isOnlyElsewhere)
    }

    private static func rejectionReason(_ window: WindowEntry, role: String) -> String? {
        if role != kAXWindowRole { return "role" }
        // Public attributes can't tell these apart: some apps expose AXDialog elements backed by no real window.
        if window.id == nil { return "no_window_id" }
        switch window.subrole {
        case kAXStandardWindowSubrole: return nil
        case kAXDialogSubrole: return window.title.isEmpty ? "untitled_dialog" : nil
        default: return "subrole"
        }
    }

    /// Diagnostic report. The public off-screen heuristic stays here only as the comparison that justified going private.
    static func writeReport() {
        let apps = scan()
        let current = PrivateAPI.currentSpaceIDs()
        let all = WindowServer.windows(onScreenOnly: false)
        var out = "currentSpaces=\(current.sorted())\n"
        for app in apps {
            let serverWindows = all.filter { $0.pid == app.pid && $0.isLargeEnough }
            let publicOnlyOther = app.windows.isEmpty && serverWindows.contains { !$0.isOnScreen }
            let verdict = publicOnlyOther == app.hasWindowsOnlyInOtherSpaces ? "" : "  DISAGREE"
            out += "\n\(app.name) pid=\(app.pid) soloAltriSpace public=\(publicOnlyOther) private=\(app.hasWindowsOnlyInOtherSpaces)\(verdict)\n"
            if app.windows.isEmpty {
                for window in serverWindows {
                    out += "  srv wid=\(window.id) onScreen=\(window.isOnScreen) spaces=\(PrivateAPI.spaces(of: window.id))\n"
                }
            }
            for window in app.windows {
                let spaces = window.id.map(PrivateAPI.spaces(of:)) ?? []
                let leak = !window.isMinimized && !spaces.isEmpty && Set(spaces).isDisjoint(with: current)
                out += "  ok  wid=\(window.id.map(String.init) ?? "?") \(window.isMinimized ? "[min] " : "")\(window.subrole) spaces=\(spaces)\(leak ? " ALTRO_SPACE" : "") \"\(window.title)\"\n"
            }
            for entry in app.rejected { out += "  no  \(entry)\n" }
        }
        let count = apps.reduce(0) { $0 + $1.windows.count }
        out += "\ntotale app=\(apps.count) finestre=\(count)\n"
        try? out.write(to: Log.directory.appendingPathComponent("list.txt"), atomically: true, encoding: .utf8)
    }
}
