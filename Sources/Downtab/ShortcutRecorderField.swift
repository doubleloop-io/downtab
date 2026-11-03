import AppKit
import Carbon
import SwitcherCore

/// Shows a shortcut; clicked (or pressed with Space or Return), it records the next key typed with its modifiers.
/// Built in-house: a few dozen lines did not justify a third-party recorder.
final class ShortcutRecorderField: NSView {
    private enum State: Equatable {
        case showing
        case recording(held: Set<ShortcutModifier>)
    }

    var shortcut: Shortcut {
        didSet { refresh() }
    }
    /// Called when recording starts and when it ends, recorded or cancelled.
    var onRecordingChanged: (Bool) -> Void = { _ in }
    var onRecord: (Shortcut) -> Void = { _ in }

    private var state = State.showing {
        didSet { refresh() }
    }
    private let text = NSTextField(labelWithString: "")

    init(shortcut: Shortcut, accessibilityName: String) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        focusRingType = .default
        text.alignment = .center
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 160),
            heightAnchor.constraint(equalToConstant: 26),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(accessibilityName)
        setAccessibilityHelp("Press to record a new shortcut, then type it. Esc cancels.")
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    var isRecording: Bool { state != .showing }

    func cancelRecording() {
        guard isRecording else { return }
        state = .showing
        onRecordingChanged(false)
    }

    // MARK: Responder

    override var acceptsFirstResponder: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override func mouseDown(with event: NSEvent) {
        focusAndRecord()
    }

    override func accessibilityPerformPress() -> Bool {
        focusAndRecord()
        return true
    }

    override func resignFirstResponder() -> Bool {
        cancelRecording()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = Int(event.keyCode)
        guard isRecording else {
            if keyCode == kVK_Space || keyCode == kVK_Return {
                startRecording()
            } else {
                super.keyDown(with: event)
            }
            return
        }
        let modifiers = Self.modifiers(of: event.modifierFlags)
        if keyCode == kVK_Escape && modifiers.isEmpty {
            cancelRecording()
            return
        }
        state = .showing
        onRecordingChanged(false)
        onRecord(Shortcut(keyCode: keyCode, modifiers: modifiers))
    }

    /// ⌘ combinations arrive here instead of `keyDown`; while recording they must not trigger menu items.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return super.flagsChanged(with: event) }
        state = .recording(held: Self.modifiers(of: event.modifierFlags))
    }

    // MARK: Drawing

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }

    // MARK: Private

    private func focusAndRecord() {
        window?.makeFirstResponder(self)
        startRecording()
    }

    private func startRecording() {
        guard !isRecording else { return }
        state = .recording(held: [])
        onRecordingChanged(true)
    }

    private func refresh() {
        switch state {
        case .showing:
            text.stringValue = ShortcutLabel.text(for: shortcut)
            text.textColor = .labelColor
        case .recording(let held):
            text.stringValue = held.isEmpty ? "Type shortcut" : ShortcutLabel.modifiersText(held)
            text.textColor = .secondaryLabelColor
        }
        setAccessibilityValue(text.stringValue)
        needsDisplay = true
    }

    private static func modifiers(of flags: NSEvent.ModifierFlags) -> Set<ShortcutModifier> {
        Set(ShortcutModifier.allCases.filter { flags.contains($0.eventFlag) })
    }
}
