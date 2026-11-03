import AppKit
import SwitcherCore

/// The App shortcut and Window shortcut recorders, with their rejection messages and Restore Defaults,
/// then the launch at login toggle.
final class PreferencesWindow: NSWindow, NSWindowDelegate {
    private let settings: ShortcutSettings
    private let launchAtLogin = LaunchAtLogin()
    private let launchAtLoginToggle = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private var launchAtLoginApprovalRow: NSGridRow?
    private var recorders: [ShortcutSlot: ShortcutRecorderField] = [:]
    private var messages: [ShortcutSlot: NSTextField] = [:]
    private var messageRows: [ShortcutSlot: NSGridRow] = [:]

    init(settings: ShortcutSettings) {
        self.settings = settings
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Downtab Preferences"
        isReleasedWhenClosed = false
        delegate = self
        contentView = makeContent()
        fitToContent()
        center()
    }

    func open() {
        showCurrentShortcuts()
        showLaunchAtLogin()
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        // AppKit focuses the first recorder on open; nothing should look selected until the user picks a field.
        makeFirstResponder(nil)
    }

    // Recording suspends the shortcuts: leaving the window must never leave them off.
    func windowDidResignKey(_ notification: Notification) {
        cancelRecording()
    }

    // The user may have changed the login item in System Settings meanwhile.
    func windowDidBecomeKey(_ notification: Notification) {
        showLaunchAtLogin()
    }

    private enum Layout {
        static let margin: CGFloat = 20
        static let fieldColumnWidth: CGFloat = 240
        static let rowGap: CGFloat = 10
        static let messageGap: CGFloat = 4
        static let hintGap: CGFloat = 14
        static let buttonGap: CGFloat = 16
        static let sectionGap: CGFloat = 20
    }

    /// Two columns: trailing-aligned labels, then fields with their messages, the hint and Restore Defaults.
    private func makeContent() -> NSView {
        let hint = NSTextField(
            wrappingLabelWithString: "Click a field, then type the new shortcut. Esc cancels. "
                + "The same shortcut with ⇧ goes back."
        )
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = Layout.fieldColumnWidth
        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(toggleLaunchAtLogin)

        let grid = NSGridView(
            views: ShortcutSlot.allCases.flatMap(rows(for:)) + [
                [NSGridCell.emptyContentView, hint],
                [NSGridCell.emptyContentView, restore],
                [NSGridCell.emptyContentView, launchAtLoginToggle],
                [NSGridCell.emptyContentView, makeApprovalNote()],
            ]
        )
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 0
        grid.columnSpacing = 8
        grid.yPlacement = .center
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.column(at: 1).width = Layout.fieldColumnWidth
        for (index, slot) in ShortcutSlot.allCases.enumerated() {
            grid.row(at: 2 * index).topPadding = index == 0 ? 0 : Layout.rowGap
            let messageRow = grid.row(at: 2 * index + 1)
            messageRow.topPadding = Layout.messageGap
            messageRow.isHidden = true
            messageRows[slot] = messageRow
        }
        let hintIndex = 2 * ShortcutSlot.allCases.count
        grid.row(at: hintIndex).topPadding = Layout.hintGap
        grid.row(at: hintIndex + 1).topPadding = Layout.buttonGap
        grid.row(at: hintIndex + 2).topPadding = Layout.sectionGap
        let approvalRow = grid.row(at: hintIndex + 3)
        approvalRow.topPadding = Layout.messageGap
        approvalRow.isHidden = true
        launchAtLoginApprovalRow = approvalRow

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: Layout.margin),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Layout.margin),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Layout.margin),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Layout.margin),
        ])
        return content
    }

    /// Sizes the window to its content, keeping its top edge where it is.
    private func fitToContent() {
        guard let contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let size = contentView.fittingSize
        let newFrame = frameRect(forContentRect: NSRect(origin: .zero, size: size))
        setFrame(
            NSRect(x: frame.minX, y: frame.maxY - newFrame.height, width: newFrame.width, height: newFrame.height),
            display: isVisible
        )
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
        message.preferredMaxLayoutWidth = Layout.fieldColumnWidth
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

    private func makeApprovalNote() -> NSView {
        let note = NSTextField(
            wrappingLabelWithString: "Turned off in System Settings. "
                + "Turn Downtab on in Login Items to launch it at login."
        )
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = Layout.fieldColumnWidth
        let open = NSButton(title: "Open Login Items…", target: self, action: #selector(openLoginItems))
        let stack = NSStackView(views: [note, open])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.messageGap
        return stack
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.set(launchAtLoginToggle.state == .on)
        showLaunchAtLogin()
    }

    @objc private func openLoginItems() {
        launchAtLogin.openSystemSettings()
    }

    /// The toggle shows the stored choice; the note appears when System Settings overrides it.
    private func showLaunchAtLogin() {
        let wanted = launchAtLogin.isWanted
        launchAtLoginToggle.state = wanted ? .on : .off
        launchAtLoginApprovalRow?.isHidden = !(wanted && launchAtLogin.status == .needsApproval)
        fitToContent()
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
        messageRows[slot]?.isHidden = text == nil
        fitToContent()
        guard let text else { return }
        NSAccessibility.post(
            element: message,
            notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
    }
}
