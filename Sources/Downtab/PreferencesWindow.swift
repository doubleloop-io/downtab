import AppKit
import SwitcherCore

/// The App shortcut and Window shortcut recorders, with their rejection messages and Restore Defaults.
final class PreferencesWindow: NSWindow, NSWindowDelegate {
    private let settings: ShortcutSettings
    private var recorders: [ShortcutSlot: ShortcutRecorderField] = [:]
    private var messages: [ShortcutSlot: NSTextField] = [:]

    init(settings: ShortcutSettings) {
        self.settings = settings
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Downtab Preferences"
        isReleasedWhenClosed = false
        delegate = self
        contentView = makeContent()
        center()
    }

    func open() {
        for slot in ShortcutSlot.allCases {
            recorders[slot]?.shortcut = settings.current[slot]
            show(nil, for: slot)
        }
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    // Recording suspends the shortcuts: leaving the window must never leave them off.
    func windowDidResignKey(_ notification: Notification) {
        for recorder in recorders.values { recorder.cancelRecording() }
    }

    private func makeContent() -> NSView {
        let grid = NSGridView(views: ShortcutSlot.allCases.flatMap(rows(for:)))
        grid.rowSpacing = 6
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline

        let hint = NSTextField(
            wrappingLabelWithString: "Click a field, then type the new shortcut. Esc cancels. "
                + "The same shortcut with ⇧ goes back."
        )
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))

        let stack = NSStackView(views: [grid, hint, restore])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        hint.widthAnchor.constraint(equalToConstant: 420).isActive = true
        return stack
    }

    private func rows(for slot: ShortcutSlot) -> [[NSView]] {
        let name = slot == .app ? "App shortcut" : "Window shortcut"
        let recorder = ShortcutRecorderField(shortcut: settings.current[slot], accessibilityName: name)
        recorder.onRecordingChanged = { [weak self] recording in
            guard let self else { return }
            if recording {
                show(nil, for: slot)
                settings.suspendWhileRecording()
            } else {
                settings.resumeAfterRecording()
            }
        }
        recorder.onRecord = { [weak self] shortcut in self?.record(shortcut, for: slot) }
        let message = NSTextField(wrappingLabelWithString: "")
        message.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        message.textColor = .systemRed
        message.isHidden = true
        message.preferredMaxLayoutWidth = 280
        recorders[slot] = recorder
        messages[slot] = message
        return [
            [NSTextField(labelWithString: "\(name):"), recorder],
            [NSGridCell.emptyContentView, message],
        ]
    }

    private func record(_ shortcut: Shortcut, for slot: ShortcutSlot) {
        switch settings.record(shortcut, for: slot) {
        case .valid:
            recorders[slot]?.shortcut = shortcut
            show(nil, for: slot)
        case .rejected(let rejection):
            show("\(ShortcutLabel.text(for: shortcut)): \(rejection.message)", for: slot)
        }
    }

    @objc private func restoreDefaults() {
        for recorder in recorders.values { recorder.cancelRecording() }
        let refused = settings.restoreDefaults()
        for slot in ShortcutSlot.allCases {
            recorders[slot]?.shortcut = settings.current[slot]
            show(refused.contains(slot) ? ShortcutRejection.usedBySystem.message : nil, for: slot)
        }
    }

    private func show(_ text: String?, for slot: ShortcutSlot) {
        guard let message = messages[slot] else { return }
        message.stringValue = text ?? ""
        message.isHidden = text == nil
        guard let text else { return }
        NSAccessibility.post(
            element: message,
            notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
    }
}
