import AppKit

/// The menu bar icon's states. A missing permission wins over a pending Update: without it Downtab does nothing.
enum MenuBarIcon {
    private enum Metrics {
        static let dotDiameter: CGFloat = 6
        /// Cleared around the dot, so it reads apart from the symbol's strokes.
        static let dotGap: CGFloat = 1.5
    }

    static func image(isGranted: Bool, hasUpdate: Bool) -> NSImage? {
        guard isGranted else {
            return NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Downtab: Accessibility permission missing")
        }
        guard hasUpdate else {
            return NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Downtab")
        }
        return badged(NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: nil))
    }

    /// A template image, like the symbol: the menu bar tints symbol and dot alike, in light and dark.
    private static func badged(_ symbol: NSImage?) -> NSImage? {
        guard let symbol else { return nil }
        let dot = NSRect(
            x: symbol.size.width - Metrics.dotDiameter / 2, y: symbol.size.height - Metrics.dotDiameter,
            width: Metrics.dotDiameter, height: Metrics.dotDiameter)
        let size = NSSize(width: symbol.size.width + Metrics.dotDiameter / 2, height: symbol.size.height)
        let image = NSImage(size: size, flipped: false) { _ in
            symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: dot.insetBy(dx: -Metrics.dotGap, dy: -Metrics.dotGap)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Downtab: update available"
        return image
    }
}
