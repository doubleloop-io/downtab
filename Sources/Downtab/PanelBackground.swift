import AppKit

/// Where the Switcher and the Window list branch on the OS version for their background (`Palette` branches for
/// colors): system glass on macOS 26+, following the system appearance and glass settings; earlier, the panel's
/// own background on a dark appearance.
enum PanelBackground {
    /// Makes `content` the panel's content, on its background, and sets the panel's appearance before macOS 26.
    static func install(_ content: NSView, in panel: NSPanel, cornerRadius: CGFloat, preGlass: () -> NSView) {
        let background: NSView
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            // In a key window the glass fills its whole rectangle past its rounded corners, and the shadow follows
            // that rectangle (#57): a rounded clip trims both.
            background = NSView()
            background.wantsLayer = true
            background.layer?.cornerRadius = cornerRadius
            background.layer?.masksToBounds = true
            glass.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(glass)
            NSLayoutConstraint.activate(glass.constraintsPinningEdges(to: background))
        } else {
            // The prototype is a dark HUD whatever the system appearance.
            panel.appearance = NSAppearance(named: .darkAqua)
            background = preGlass()
            background.addSubview(content)
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(content.constraintsPinningEdges(to: background))
        panel.contentView = background
    }
}
