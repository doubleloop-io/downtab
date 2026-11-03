import AppKit
import SwitcherCore

/// The Accessibility permission status, the App shortcut and Window shortcut recorders, with their rejection
/// messages and Restore Defaults.
final class PreferencesWindow: NSWindow, NSWindowDelegate {
    private static let accessibilitySettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    private let settings: ShortcutSettings
    private let permissionBox = NSBox()
    private let permissionStatus = NSTextField(wrappingLabelWithString: "")
    private let openSystemSettings = NSButton(title: "Open System Settings", target: nil, action: nil)
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
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        // AppKit focuses the first recorder on open; nothing should look selected until the user picks a field.
        makeFirstResponder(nil)
    }

    /// A missing permission is highlighted until granted: the shortcuts do nothing without it.
    func showPermission(isGranted: Bool) {
        permissionStatus.stringValue =
            isGranted
            ? "Granted"
            : "Not granted: the shortcuts do nothing until you allow Downtab in System Settings."
        permissionStatus.textColor = isGranted ? .secondaryLabelColor : .labelColor
        permissionBox.fillColor = isGranted ? .clear : .systemYellow.withAlphaComponent(0.25)
        permissionBox.borderColor = isGranted ? .clear : .systemYellow
        openSystemSettings.isHidden = isGranted
        fitToContent()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = Self.accessibilitySettings else { return }
        NSWorkspace.shared.open(url)
    }

    // Recording suspends the shortcuts: leaving the window must never leave them off.
    func windowDidResignKey(_ notification: Notification) {
        cancelRecording()
    }

    private enum Layout {
        static let margin: CGFloat = 20
        static let fieldColumnWidth: CGFloat = 240
        static let rowGap: CGFloat = 10
        static let messageGap: CGFloat = 4
        static let hintGap: CGFloat = 14
        static let buttonGap: CGFloat = 16
        static let permissionGap: CGFloat = 16
        static let permissionPadding: CGFloat = 6
    }

    private func makePermissionBox() -> NSView {
        permissionStatus.preferredMaxLayoutWidth = Layout.fieldColumnWidth - 2 * Layout.permissionPadding
        openSystemSettings.target = self
        openSystemSettings.action = #selector(openAccessibilitySettings)
        let stack = NSStackView(views: [permissionStatus, openSystemSettings])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        permissionBox.boxType = .custom
        permissionBox.cornerRadius = 6
        permissionBox.borderWidth = 1
        permissionBox.contentViewMargins = NSSize(width: Layout.permissionPadding, height: Layout.permissionPadding)
        permissionBox.contentView = stack
        permissionBox.setAccessibilityLabel("Accessibility permission")
        return permissionBox
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

        let grid = NSGridView(
            views: [[NSTextField(labelWithString: "Accessibility:"), makePermissionBox()]]
                + ShortcutSlot.allCases.flatMap(rows(for:)) + [
                    [NSGridCell.emptyContentView, hint],
                    [NSGridCell.emptyContentView, restore],
                ]
        )
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 0
        grid.columnSpacing = 8
        grid.yPlacement = .center
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.column(at: 1).width = Layout.fieldColumnWidth
        grid.row(at: 0).yPlacement = .top
        for (index, slot) in ShortcutSlot.allCases.enumerated() {
            grid.row(at: 1 + 2 * index).topPadding = index == 0 ? Layout.permissionGap : Layout.rowGap
            let messageRow = grid.row(at: 2 + 2 * index)
            messageRow.topPadding = Layout.messageGap
            messageRow.isHidden = true
            messageRows[slot] = messageRow
        }
        grid.row(at: grid.numberOfRows - 2).topPadding = Layout.hintGap
        grid.row(at: grid.numberOfRows - 1).topPadding = Layout.buttonGap

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
