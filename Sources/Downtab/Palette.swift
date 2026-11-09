import AppKit

/// Colors shared by the Switcher and its Window list. On macOS 26+ they sit on system glass and follow the system
/// appearance and contrast; earlier, they are prototype variant A's dark HUD
/// (`docs/adr/assets/prototype-switcher.html`).
enum Palette {
    private static let offWhite = NSColor(srgbRed: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)

    static let border = onGlass(
        adaptive(light: 0.1, dark: 0.14), preGlass: NSColor(white: 1, alpha: 0.12))
    static let text = onGlass(.labelColor, preGlass: offWhite)
    static let muted = onGlass(
        .secondaryLabelColor, preGlass: NSColor(srgbRed: 0xA1 / 255, green: 0xA1 / 255, blue: 0xAA / 255, alpha: 1))
    static let accent = NSColor(srgbRed: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255, alpha: 1)
    static let selectedTile = onGlass(adaptive(light: 0.12, dark: 0.22), preGlass: NSColor(white: 1, alpha: 0.2))
    static let parentTile = onGlass(adaptive(light: 0.06, dark: 0.11), preGlass: NSColor(white: 1, alpha: 0.1))
    /// The Dock's notification red.
    static let notificationBadge = NSColor(srgbRed: 0xFF / 255, green: 0x3B / 255, blue: 0x30 / 255, alpha: 1)
    /// Before macOS 26 only: the HUD material alone lets bright windows show through.
    static let hudTint = NSColor(srgbRed: 30 / 255, green: 30 / 255, blue: 34 / 255, alpha: 0.8)
    /// Before macOS 26 only.
    static let windowListFill = NSColor(srgbRed: 36 / 255, green: 36 / 255, blue: 40 / 255, alpha: 0.96)

    /// With Increase contrast on, tiles and borders double their opacity.
    private static let highContrastFactor: CGFloat = 2

    private static func onGlass(_ glass: NSColor, preGlass: NSColor) -> NSColor {
        if #available(macOS 26, *) { glass } else { preGlass }
    }

    /// Black over a light glass, white over a dark one, at the given opacities.
    private static func adaptive(light: CGFloat, dark: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            ])
            let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let isHighContrast = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            let alpha = (isDark ? dark : light) * (isHighContrast ? highContrastFactor : 1)
            return NSColor(white: isDark ? 1 : 0, alpha: alpha)
        }
    }
}
