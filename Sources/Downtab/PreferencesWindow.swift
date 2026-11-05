import AppKit
import SwitcherCore

final class PreferencesWindow: NSWindow, NSWindowDelegate {
    private static let accessibilitySettings = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")

    private let settings: ShortcutSettings
    private let permissionBox = HighlightBox()
    private let permissionStatus = NSTextField(wrappingLabelWithString: "")
    private let openSystemSettings = NSButton(title: "Open System Settings", target: nil, action: nil)
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

    /// A missing permission is highlighted until granted: the shortcuts do nothing without it.
    func showPermission(isGranted: Bool) {
        permissionStatus.stringValue =
            isGranted
            ? "Granted"
            : "Not granted: the shortcuts do nothing until you allow Downtab in System Settings."
        permissionStatus.textColor = isGranted ? .secondaryLabelColor : .labelColor
        permissionBox.isHighlighted = !isGranted
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
        static let permissionGap: CGFloat = 16
        static let permissionPadding: CGFloat = 6
    }

    private func makePermissionBox() -> NSView {
        permissionStatus.preferredMaxLayoutWidth = Layout.fieldColumnWidth - 2 * Layout.permissionPadding
        openSystemSettings.target = self
        openSystemSettings.action = #selector(openAccessibilitySettings)
        permissionBox.setContent(
            Self.leadingColumn([permissionStatus, openSystemSettings], spacing: 6),
            padding: Layout.permissionPadding)
        permissionBox.setAccessibilityLabel("Accessibility permission")
        return permissionBox
    }

    private func makeContent() -> NSView {
        let grid = makeGrid()
        grid.translatesAutoresizingMaskIntoConstraints = false
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

    private func makeGrid() -> NSGridView {
        let grid = NSGridView()
        @discardableResult func addRow(_ label: String?, _ field: NSView, topPadding: CGFloat) -> NSGridRow {
            let labelView = label.map { NSTextField(labelWithString: $0) } ?? NSGridCell.emptyContentView
            let row = grid.addRow(with: [labelView, field])
            row.topPadding = topPadding
            return row
        }

        let permissionRow = addRow("Accessibility:", makePermissionBox(), topPadding: 0)
        permissionRow.yPlacement = .top
        permissionRow.cell(at: 1).xPlacement = .fill
        // The label follows the status text, which the box's padding moves when the permission is missing.
        if let label = permissionRow.cell(at: 0).contentView {
            permissionRow.cell(at: 0).yPlacement = .none
            label.firstBaselineAnchor.constraint(equalTo: permissionStatus.firstBaselineAnchor).isActive = true
        }
        for slot in ShortcutSlot.allCases {
            let (recorder, message) = makeRecorder(for: slot)
            let isFirst = slot == ShortcutSlot.allCases.first
            addRow("\(slot.name):", recorder, topPadding: isFirst ? Layout.permissionGap : Layout.rowGap)
            let messageRow = addRow(nil, message, topPadding: Layout.messageGap)
            messageRow.isHidden = true
            messageRows[slot] = messageRow
        }
        let hint = Self.note(
            "Click a field, then type the new shortcut. Esc cancels. The same shortcut with ⇧ goes back.",
            color: .secondaryLabelColor)
        addRow(nil, hint, topPadding: Layout.hintGap)
        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        addRow(nil, restore, topPadding: Layout.buttonGap)
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(toggleLaunchAtLogin)
        addRow(nil, launchAtLoginToggle, topPadding: Layout.sectionGap)
        let approvalRow = addRow(nil, makeApprovalNote(), topPadding: Layout.messageGap)
        approvalRow.isHidden = true
        launchAtLoginApprovalRow = approvalRow

        grid.rowSpacing = 0
        grid.columnSpacing = 8
        grid.yPlacement = .center
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.column(at: 1).width = Layout.fieldColumnWidth
        return grid
    }

    private static func note(_ text: String, color: NSColor) -> NSTextField {
        let note = NSTextField(wrappingLabelWithString: text)
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = color
        note.preferredMaxLayoutWidth = Layout.fieldColumnWidth
        return note
    }

    private static func leadingColumn(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
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

    private func makeRecorder(for slot: ShortcutSlot) -> (ShortcutRecorderField, NSTextField) {
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
        let message = Self.note("", color: .systemRed)
        recorders[slot] = recorder
        messages[slot] = message
        return (recorder, message)
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
        let note = Self.note(
            "Turned off in System Settings. Turn Downtab on in Login Items to launch it at login.",
            color: .secondaryLabelColor)
        let open = NSButton(title: "Open Login Items…", target: self, action: #selector(openLoginItems))
        return Self.leadingColumn([note, open], spacing: Layout.messageGap)
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

/// A yellow rounded highlight around its content. NSBox ignores Auto Layout for its content view, so the
/// grid sized it to a single line and the wrapped status overflowed onto the shortcut rows.
private final class HighlightBox: NSView {
    private var paddingConstraints: [NSLayoutConstraint] = []
    private var padding: CGFloat = 0

    /// Without the highlight, the content must sit where the other fields start, not inset by the padding.
    var isHighlighted = false {
        didSet {
            for constraint in paddingConstraints { constraint.constant = isHighlighted ? padding : 0 }
            needsDisplay = true
        }
    }

    func setContent(_ content: NSView, padding: CGFloat) {
        self.padding = padding
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        paddingConstraints = [
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ]
        NSLayoutConstraint.activate(paddingConstraints)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isHighlighted else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        NSColor.systemYellow.withAlphaComponent(0.25).setFill()
        path.fill()
        NSColor.systemYellow.setStroke()
        path.stroke()
    }
}
