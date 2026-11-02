import AppKit

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .windowBackgroundColor
        isReleasedWhenClosed = false
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.frame.origin = NSPoint(x: 12, y: 12)
        contentView?.addSubview(label)
    }

    func show(_ text: String) {
        label.stringValue = text
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 24, height: label.frame.height + 24)
        let screen = NSScreen.main?.visibleFrame ?? .zero
        setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                        width: size.width, height: size.height), display: false)
        makeKeyAndOrderFront(nil)
        displayIfNeeded()
    }
}
