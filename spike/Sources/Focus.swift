import AppKit
import ApplicationServices

enum FocusStrategy: String {
    case publicAPI = "public"
    case privateAPI = "private"
}

enum Focus {
    private static let queue = DispatchQueue(label: "focus")

    static func raise(_ window: WindowEntry?, of app: AppEntry, strategy: FocusStrategy, then done: @escaping () -> Void) {
        queue.async {
            let before = WindowServer.windows(onScreenOnly: true)
            var steps: [String] = []
            if let window, window.isMinimized {
                steps.append("unminimize=\(AX.set(window.element, kAXMinimizedAttribute, false).rawValue)")
            }
            switch strategy {
            case .publicAPI: raisePublicly(window, app, &steps)
            case .privateAPI: raisePrivately(window, app, &steps)
            }
            done()
            queue.asyncAfter(deadline: .now() + 0.3) { verify(window, app, strategy, steps, before) }
        }
    }

    private static func raisePublicly(_ window: WindowEntry?, _ app: AppEntry, _ steps: inout [String]) {
        let activated = NSRunningApplication(processIdentifier: app.pid)?.activate() ?? false
        steps.append("activate=\(activated)")
        let appElement = AXUIElementCreateApplication(app.pid)
        steps.append("frontmost=\(AX.set(appElement, kAXFrontmostAttribute, true).rawValue)")
        guard let window else { return }
        steps.append("main=\(AX.set(window.element, kAXMainAttribute, true).rawValue)")
        steps.append("raise=\(AXUIElementPerformAction(window.element, kAXRaiseAction as CFString).rawValue)")
    }

    private static func raisePrivately(_ window: WindowEntry?, _ app: AppEntry, _ steps: inout [String]) {
        guard let window, let id = window.id, let result = PrivateAPI.frontWindow(pid: app.pid, windowID: id) else {
            steps.append("private_unavailable")
            NSRunningApplication(processIdentifier: app.pid)?.activate()
            return
        }
        steps.append("front=\(result.front) key=\(result.key)")
        steps.append("raise=\(AXUIElementPerformAction(window.element, kAXRaiseAction as CFString).rawValue)")
        queue.asyncAfter(deadline: .now() + 0.15) {
            if WindowServer.windows(onScreenOnly: true).first?.id != id {
                let again = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString).rawValue
                Log.write("focus_reraise wid=\(id) ax=\(again)")
            }
        }
    }

    private static func verify(_ window: WindowEntry?, _ app: AppEntry, _ strategy: FocusStrategy, _ steps: [String], _ before: [ServerWindow]) {
        let after = WindowServer.windows(onScreenOnly: true)
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.pid
        let element = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        let isKey = window.map { AX.same(AX.element(element, kAXFocusedWindowAttribute), $0.element) }
        let isTop = window?.id.map { after.first?.id == $0 }
        let moved = siblingsMovedForward(target: window?.id, pid: app.pid, before: before, after: after)
        Log.write("focus verified strategy=\(strategy.rawValue) app=\"\(app.name)\" title=\"\(window?.title ?? "")\" wasMinimized=\(window?.isMinimized ?? false) frontmost=\(frontmost) key=\(describe(isKey)) top=\(describe(isTop)) siblingsMovedForward=\(moved) steps=\(steps.joined(separator: ","))")
    }

    /// Rank is computed without the target: its own promotion must not count as its siblings moving.
    private static func siblingsMovedForward(target: CGWindowID?, pid: pid_t, before: [ServerWindow], after: [ServerWindow]) -> Int {
        let beforeIDs = before.map(\.id).filter { $0 != target }
        let afterIDs = after.map(\.id).filter { $0 != target }
        return after.filter { $0.pid == pid && $0.id != target }.filter { sibling in
            guard let was = beforeIDs.firstIndex(of: sibling.id), let now = afterIDs.firstIndex(of: sibling.id) else { return false }
            return now < was
        }.count
    }

    private static func describe(_ value: Bool?) -> String {
        value.map(String.init) ?? "n/a"
    }
}
