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
        showCurrentShortcuts()
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    // Recording suspends the shortcuts: leaving the window must never leave them off.
    func windowDidResignKey(_ notification: Notification) {
        cancelRecording()
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
        let recorder = ShortcutRecorderField(shortcut: settings.current[slot], accessibilityName: slot.name)
        recorder.onRecordingChanged = { [weak self] recording in
            guard let self else { return }
            if recording {
                show(nil, for: slot)
                settings.suspendWhileRecording()
            } else {
                settings.resumeAfterRecording()
                showCurrentShortcuts()
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
            [NSTextField(labelWithString: "\(slot.name):"), recorder],
            [NSGridCell.emptyContentView, message],
        ]
    }

    private func record(_ shortcut: Shortcut, for slot: ShortcutSlot) {
        switch settings.record(shortcut, for: slot) {
        case .valid:
            showCurrentShortcuts()
        case .rejected(let rejection):
            show(rejection, of: shortcut, for: slot)
        }
    }

    @objc private func restoreDefaults() {
        cancelRecording()
        showCurrentShortcuts(restoreFailures: settings.restoreDefaults())
    }

    private func cancelRecording() {
        for recorder in recorders.values { recorder.cancelRecording() }
    }

    /// Each slot shows why its default failed to register, if it did, otherwise why its current shortcut did.
    private func showCurrentShortcuts(restoreFailures: [ShortcutSlot: ShortcutRejection] = [:]) {
        for slot in ShortcutSlot.allCases {
            recorders[slot]?.shortcut = settings.current[slot]
            if let rejection = restoreFailures[slot] {
                show(rejection, of: Shortcuts.defaults[slot], for: slot)
            } else if let failure = settings.failures[slot] {
                show(failure, of: settings.current[slot], for: slot)
            } else {
                show(nil, for: slot)
            }
        }
    }

    private func show(_ rejection: ShortcutRejection, of shortcut: Shortcut, for slot: ShortcutSlot) {
        show("\(ShortcutLabel.text(for: shortcut)): \(rejection.message)", for: slot)
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
