import AppKit
import SwitcherCore

/// The selected app's Window list, dropped under its icon with a caret pointing at it, as in prototype variant A
/// (`docs/prototype-switcher.html`). Never key: the Switcher keeps the keyboard.
final class WindowListPanel: NSPanel {
    private let background = CaretBackground()
    private let headerIcon = NSImageView()
    private let header = NSTextField(labelWithString: "")
    private let scroll = NSScrollView()
    private let rows = FlippedView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)
        title = "Window list"
        contentView = background

        background.setAccessibilityElement(true)
        background.setAccessibilityRole(.list)
        background.setAccessibilityLabel("Window list")
        headerIcon.imageScaling = .scaleProportionallyUpOrDown
        headerIcon.setAccessibilityElement(false)
        header.font = .systemFont(ofSize: Metrics.headerFontSize)
        header.textColor = Palette.muted
        header.lineBreakMode = .byTruncatingTail
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = rows
        for view in [headerIcon, header, scroll] {
            background.addSubview(view)
        }
    }

    /// `anchor` is in screen coordinates: x is the selected icon's center, y the Switcher's bottom edge.
    func show(_ entry: AppRowEntry, selectedWindow: Int, icon: NSImage?, below anchor: NSPoint, on screen: NSScreen?) {
        let screenFrame = screen?.frame ?? NSRect(x: anchor.x - 200, y: 0, width: 400, height: anchor.y)
        let width = min(Metrics.width, screenFrame.width - 2 * Metrics.screenGutter)
        let listHeight = min(CGFloat(entry.windows.count) * Metrics.rowHeight, Metrics.maxListHeight)
        let height = Metrics.caretHeight + 2 * Metrics.padding + Metrics.headerHeight + listHeight
        let x = min(
            max(anchor.x - width / 2, screenFrame.minX + Metrics.screenGutter),
            screenFrame.maxX - width - Metrics.screenGutter)
        let top = anchor.y - Metrics.gapBelowSwitcher + Metrics.caretHeight
        setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: false)
        background.caretX = anchor.x - x

        layoutHeader(entry, icon: icon, width: width)
        layoutRows(entry.windows, selected: selectedWindow, width: width, listHeight: listHeight)
        background.needsDisplay = true
        orderFront(nil)
    }

    private func layoutHeader(_ entry: AppRowEntry, icon: NSImage?, width: CGFloat) {
        let top = Metrics.caretHeight + Metrics.padding + Metrics.headerTopPadding
        headerIcon.image = icon
        headerIcon.frame = NSRect(
            x: Metrics.padding + Metrics.headerSidePadding, y: top, width: Metrics.headerIcon,
            height: Metrics.headerIcon)
        let count = entry.windows.count
        header.stringValue = "\(entry.name) · \(count) \(count == 1 ? "window" : "windows")"
        let textX = headerIcon.frame.maxX + Metrics.headerIconGap
        header.frame = NSRect(
            x: textX, y: top, width: width - textX - Metrics.padding - Metrics.headerSidePadding,
            height: Metrics.headerIcon)
    }

    private func layoutRows(_ windows: [WindowListEntry], selected: Int, width: CGFloat, listHeight: CGFloat) {
        let listWidth = width - 2 * Metrics.padding
        scroll.frame = NSRect(
            x: Metrics.padding, y: Metrics.caretHeight + Metrics.padding + Metrics.headerHeight, width: listWidth,
            height: listHeight)
        let views = windows.enumerated().map { index, window in
            WindowRow(title: window.title, isSelected: index == selected)
        }
        rows.subviews = views
        for (index, row) in views.enumerated() {
            row.frame = NSRect(x: 0, y: CGFloat(index) * Metrics.rowHeight, width: listWidth, height: Metrics.rowHeight)
        }
        rows.frame = NSRect(x: 0, y: 0, width: listWidth, height: CGFloat(windows.count) * Metrics.rowHeight)
        background.setAccessibilityChildren(views)
        background.setAccessibilitySelectedChildren(views.filter(\.isSelected))
        if let selectedRow = views.first(where: \.isSelected) {
            selectedRow.scrollToVisible(selectedRow.bounds)
        }
    }
}

/// One window: its title, on the accent color when selected.
private final class WindowRow: NSView {
    let isSelected: Bool
    private let label: NSTextField

    init(title: String, isSelected: Bool) {
        self.isSelected = isSelected
        label = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Metrics.rowCornerRadius
        if isSelected {
            layer?.backgroundColor = Palette.accent.cgColor
        }
        label.font = .systemFont(ofSize: Metrics.rowFontSize)
        label.textColor = isSelected ? .white : Palette.text
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityElement(false)
        addSubview(label)

        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityRoleDescription("window")
        setAccessibilityLabel(title)
        setAccessibilitySelected(isSelected)
    }

    override func layout() {
        super.layout()
        let height = ceil(label.intrinsicContentSize.height)
        label.frame = NSRect(
            x: Metrics.rowSidePadding, y: (bounds.height - height) / 2,
            width: bounds.width - 2 * Metrics.rowSidePadding, height: height)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

/// The rounded body with the caret on its top edge, pointing at the selected icon.
private final class CaretBackground: FlippedView {
    var caretX: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        let radius = Metrics.cornerRadius
        let caret = Metrics.caretHeight
        // Half a point in, so the 1 pt border is not clipped by the window's edge.
        let minX: CGFloat = 0.5
        let maxX = bounds.width - 0.5
        let top = caret + 0.5
        let bottom = bounds.height - 0.5
        let tipX = min(max(caretX, minX + radius + caret), maxX - radius - caret)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: minX + radius, y: top))
        path.line(to: NSPoint(x: tipX - caret, y: top))
        path.line(to: NSPoint(x: tipX, y: 0.5))
        path.line(to: NSPoint(x: tipX + caret, y: top))
        path.appendArc(from: NSPoint(x: maxX, y: top), to: NSPoint(x: maxX, y: bottom), radius: radius)
        path.appendArc(from: NSPoint(x: maxX, y: bottom), to: NSPoint(x: minX, y: bottom), radius: radius)
        path.appendArc(from: NSPoint(x: minX, y: bottom), to: NSPoint(x: minX, y: top), radius: radius)
        path.appendArc(from: NSPoint(x: minX, y: top), to: NSPoint(x: minX + radius, y: top), radius: radius)
        path.close()
        Palette.windowListFill.setFill()
        path.fill()
        Palette.border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private enum Metrics {
    static let width: CGFloat = 380
    static let screenGutter: CGFloat = 16
    static let gapBelowSwitcher: CGFloat = 14
    static let caretHeight: CGFloat = 8
    static let padding: CGFloat = 6
    static let cornerRadius: CGFloat = 14
    static let headerTopPadding: CGFloat = 4
    static let headerSidePadding: CGFloat = 8
    static let headerIcon: CGFloat = 16
    static let headerIconGap: CGFloat = 7
    static let headerFontSize: CGFloat = 11.5
    /// The prototype's `padding: 4px 8px 6px` around the 16 px icon.
    static let headerHeight: CGFloat = 26
    static let rowHeight: CGFloat = 32
    static let rowSidePadding: CGFloat = 10
    static let rowCornerRadius: CGFloat = 8
    static let rowFontSize: CGFloat = 13
    static let maxListHeight: CGFloat = 300
}
