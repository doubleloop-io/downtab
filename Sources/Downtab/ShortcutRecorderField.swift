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
        layer?.cornerRadius = Self.cornerRadius
        focusRingType = .default
        text.alignment = .center
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 170),
            heightAnchor.constraint(equalToConstant: 22),
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
        let modifiers = ShortcutModifier.held(in: event.modifierFlags)
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
        state = .recording(held: ShortcutModifier.held(in: event.modifierFlags))
    }

    // MARK: Drawing

    private static let cornerRadius: CGFloat = 5

    /// Matches a bezeled text field: white in light mode, a faint lift over the window in dark mode.
    private static let fieldBackground = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.06) : NSColor.textBackgroundColor
    }

    override func updateLayer() {
        if isRecording {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
        } else {
            layer?.backgroundColor = Self.fieldBackground.cgColor
            layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
            layer?.borderWidth = 1
        }
    }

    // The accent border already marks recording; the ring only shows keyboard focus on an idle field.
    override func drawFocusRingMask() {
        guard !isRecording else { return }
        NSBezierPath(roundedRect: bounds, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
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
            text.stringValue = held.isEmpty ? "Type shortcut…" : ShortcutLabel.modifiersText(held)
            text.textColor = held.isEmpty ? .placeholderTextColor : .labelColor
        }
        setAccessibilityValue(text.stringValue)
        needsDisplay = true
        noteFocusRingMaskChanged()
    }
}
