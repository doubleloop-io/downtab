import AppKit

/// A badge on an app's icon in the Dock's look: a colored disc with the label, a pill when the label is longer than
/// 2 characters. The Notification badge and the Window count badge share it, told apart by color and corner.
final class IconBadge: NSView {
    struct Style {
        let fill: NSColor
        let text: NSColor

        static let notification = Style(fill: Palette.notificationBadge, text: .white)
        static let windowCount = Style(fill: Palette.accent, text: .white)
        /// At Window level: still tells which app the Window list belongs to, now that blue is the normal fill.
        static let windowCountOfWindowList = Style(fill: .white, text: Palette.accent)
    }

    private enum Metrics {
        /// Measured on the native ⌘Tab (macOS 27).
        static let iconRatio: CGFloat = 0.36
        /// Below this the label is unreadable, however small the icons.
        static let minDiameter: CGFloat = 16
        static let fontRatio: CGFloat = 0.55
        static let paddingRatio: CGFloat = 0.2
        /// A long label is cut rather than covering the next icon.
        static let maxWidthIconRatio: CGFloat = 0.9
        static let shadowOpacity: Float = 0.25
        static let shadowRadius: CGFloat = 2
        static let shadowOffset = CGSize(width: 0, height: -1)
    }

    init(_ text: String, iconSize: CGFloat, style: Style) {
        super.init(frame: .zero)
        let diameter = max(iconSize * Metrics.iconRatio, Metrics.minDiameter)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
        wantsLayer = true
        layer?.backgroundColor = style.fill.cgColor
        layer?.cornerRadius = diameter / 2
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = Metrics.shadowOpacity
        layer?.shadowRadius = Metrics.shadowRadius
        layer?.shadowOffset = Metrics.shadowOffset

        let font = NSFont.monospacedDigitSystemFont(ofSize: diameter * Metrics.fontRatio, weight: .regular)
        // Measured on the glyphs, not the NSTextField, whose own inset would turn 1–2 characters into a pill.
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let padding = diameter * Metrics.paddingRatio
        let width = min(max(diameter, textWidth + 2 * padding), iconSize * Metrics.maxWidthIconRatio)

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = style.text
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityElement(false)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: diameter),
            widthAnchor.constraint(equalToConstant: width),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -padding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}
