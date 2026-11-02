import AppKit
import ApplicationServices
import Carbon

private struct Selection {
    var apps: [AppEntry]
    var appIndex: Int
    var windowIndex: Int?

    var app: AppEntry? { apps.indices.contains(appIndex) ? apps[appIndex] : nil }
    var window: WindowEntry? {
        guard let app, let windowIndex, app.windows.indices.contains(windowIndex) else { return nil }
        return app.windows[windowIndex]
    }

    mutating func moveApp(by delta: Int, keepingWindowLevel: Bool = false) {
        guard !apps.isEmpty else { return }
        appIndex = (appIndex + delta + apps.count) % apps.count
        let stayAtWindowLevel = keepingWindowLevel && windowIndex != nil && app?.windows.isEmpty == false
        windowIndex = stayAtWindowLevel ? 0 : nil
    }

    mutating func moveWindow(by delta: Int) {
        guard let count = app?.windows.count, count > 0 else { return }
        windowIndex = ((windowIndex ?? (delta > 0 ? -1 : 0)) + delta + count) % count
    }

    var text: String {
        var lines = ["downtab spike   rilascio ⌥ = conferma   Esc = annulla", ""]
        for (index, app) in apps.enumerated() {
            let isSelected = index == appIndex
            lines.append("\(isSelected && windowIndex == nil ? "▸" : " ") \(app.name) (\(app.windows.count))")
            guard isSelected else { continue }
            for (position, window) in app.windows.enumerated() {
                let title = window.title.isEmpty ? "(senza titolo)" : String(window.title.prefix(70))
                lines.append("    \(position == windowIndex ? "▸" : " ") \(title)\(window.isMinimized ? "  [min]" : "")")
            }
        }
        return lines.joined(separator: "\n")
    }
}

private struct FocusContext {
    let pid: pid_t?
    let window: AXUIElement?
    let control: AXUIElement?
}

final class Switcher {
    private let panel = SwitcherPanel()
    private let inventory: Inventory
    private let strategy: FocusStrategy
    private var selection: Selection?
    private var isConfirming = false
    private var openingAt: EventTime?
    private var openingDetails = ""
    private var contextBeforeOpen: FocusContext?
    private var releasePoll: Timer?

    init(inventory: Inventory, strategy: FocusStrategy) {
        self.inventory = inventory
        self.strategy = strategy
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: panel, queue: .main) { [weak self] _ in
            self?.logOpeningIfVisible()
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return nil
        }
    }

    func handle(_ action: HotkeyAction, keyCode: UInt32, pressedAt: EventTime) {
        Log.write("hotkey action=\(action) keycode=\(keyCode) open=\(selection != nil)")
        if action == .quit { NSApp.terminate(nil); return }
        guard !isConfirming else { return }
        if selection == nil {
            open(action, pressedAt: pressedAt)
        } else {
            advance(action)
        }
        render()
        if selection != nil, !OptionReleaseTap.isOptionDown {
            Log.write("release source=before_hotkey")
            confirm()
        }
    }

    private func open(_ action: HotkeyAction, pressedAt: EventTime) {
        let snapshot = inventory.snapshot
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let visible = snapshot.apps.filter { !$0.hasWindowsOnlyInOtherSpaces }
        let apps = visible.filter { $0.pid == frontmostPID } + visible.filter { $0.pid != frontmostPID }
        var selection = Selection(apps: apps, appIndex: 0, windowIndex: nil)
        switch action {
        case .nextApp: selection.moveApp(by: apps.count > 1 ? 1 : 0)
        case .previousApp: selection.moveApp(by: -1)
        case .nextWindow: selection.windowIndex = (apps.first?.windows.count ?? 0) > 1 ? 1 : 0
        case .previousWindow: selection.moveWindow(by: -1)
        case .quit: break
        }
        self.selection = selection
        openingAt = pressedAt
        openingDetails = String(format: "apps=%d windows=%d snapshot_age_ms=%.0f", apps.count,
                                apps.reduce(0) { $0 + $1.windows.count }, Date().timeIntervalSince(snapshot.at) * 1000)
        captureContext(pid: frontmostPID)
        startReleasePoll()
    }

    private func advance(_ action: HotkeyAction) {
        switch action {
        case .nextApp: selection?.moveApp(by: 1)
        case .previousApp: selection?.moveApp(by: -1)
        case .nextWindow: selection?.moveWindow(by: 1)
        case .previousWindow: selection?.moveWindow(by: -1)
        case .quit: break
        }
    }

    private func render() {
        guard let selection else { return }
        panel.show(selection.text)
        if let openingAt {
            openingDetails += String(format: " sync_ms=%.1f", (GetCurrentEventTime() - openingAt) * 1000)
            logOpeningIfVisible()
        }
    }

    private func logOpeningIfVisible() {
        guard let openingAt, panel.occlusionState.contains(.visible) else { return }
        Log.write(String(format: "open visible_ms=%.1f %@", (GetCurrentEventTime() - openingAt) * 1000, openingDetails))
        self.openingAt = nil
    }

    private func handleKey(_ event: NSEvent) {
        Log.write("key keycode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue) repeat=\(event.isARepeat)")
        guard selection != nil, !isConfirming else { return }
        switch Int(event.keyCode) {
        case kVK_Escape: cancel(); return
        case kVK_Return, kVK_ANSI_KeypadEnter: confirm(); return
        case kVK_Tab: selection?.moveApp(by: event.modifierFlags.contains(.shift) ? -1 : 1)
        case kVK_LeftArrow: selection?.moveApp(by: -1, keepingWindowLevel: true)
        case kVK_RightArrow: selection?.moveApp(by: 1, keepingWindowLevel: true)
        case kVK_DownArrow: selection?.moveWindow(by: 1)
        case kVK_UpArrow:
            if selection?.windowIndex == 0 { selection?.windowIndex = nil } else { selection?.moveWindow(by: -1) }
        default: return
        }
        render()
    }

    func optionReleased() {
        guard selection != nil, !isConfirming else { return }
        Log.write("release source=tap")
        confirm()
    }

    /// Safety net, not the detection path: a `source=poll` line means the tap lost a release.
    private func startReleasePoll() {
        releasePoll?.invalidate()
        releasePoll = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.selection != nil, !self.isConfirming, !OptionReleaseTap.isOptionDown else { return }
            // Give the tap's main-queue hop one tick before calling it lost.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard self.selection != nil, !self.isConfirming else { return }
                Log.write("release source=poll")
                self.confirm()
            }
        }
    }

    /// The panel closes after the target is in front: some apps retake the foreground if they get the keyboard first.
    private func confirm() {
        guard let selection, let app = selection.app else { cancel(); return }
        isConfirming = true
        releasePoll?.invalidate()
        let window = selection.window ?? app.windows.first
        Focus.raise(window, of: app, strategy: strategy) { [weak self] in
            DispatchQueue.main.async { self?.close() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.close() }
    }

    private func cancel() {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.verifyFocusKept() }
    }

    private func close() {
        guard selection != nil else { return }
        panel.orderOut(nil)
        selection = nil
        openingAt = nil
        isConfirming = false
        releasePoll?.invalidate()
    }

    private func captureContext(pid: pid_t?) {
        contextBeforeOpen = nil
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let context = Switcher.readContext(pid: pid)
            DispatchQueue.main.async { self?.contextBeforeOpen = context }
        }
    }

    private static func readContext(pid: pid_t?) -> FocusContext {
        guard let pid else { return FocusContext(pid: nil, window: nil, control: nil) }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        return FocusContext(pid: pid, window: AX.element(element, kAXFocusedWindowAttribute),
                            control: AX.element(element, kAXFocusedUIElementAttribute))
    }

    private func verifyFocusKept() {
        guard let before = contextBeforeOpen else { Log.write("cancel verified context=missing"); return }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        DispatchQueue.global(qos: .userInitiated).async {
            let after = Switcher.readContext(pid: pid)
            Log.write("cancel verified sameApp=\(before.pid == after.pid) sameWindow=\(AX.same(before.window, after.window)) sameControl=\(AX.same(before.control, after.control))")
        }
    }
}
