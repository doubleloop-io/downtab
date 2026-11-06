import AppKit

/// Colors of prototype variant A (`docs/adr/assets/prototype-switcher.html`), shared by the Switcher and its
/// Window list.
enum Palette {
    static let border = NSColor(white: 1, alpha: 0.12)
    static let text = NSColor(srgbRed: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
    static let muted = NSColor(srgbRed: 0xA1 / 255, green: 0xA1 / 255, blue: 0xAA / 255, alpha: 1)
    static let accent = NSColor(srgbRed: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255, alpha: 1)
    static let hudTint = NSColor(srgbRed: 30 / 255, green: 30 / 255, blue: 34 / 255, alpha: 0.8)
    static let selectedTile = NSColor(white: 1, alpha: 0.2)
    static let parentTile = NSColor(white: 1, alpha: 0.1)
    static let badgeFill = text
    static let badgeText = NSColor(srgbRed: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
    static let windowListFill = NSColor(srgbRed: 36 / 255, green: 36 / 255, blue: 40 / 255, alpha: 0.96)
}
