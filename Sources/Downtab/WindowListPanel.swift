import AppKit
import SwitcherCore

/// The selected app's Window list, a rounded rectangle dropped under its icon (`docs/adr/0002-window-list-under-the-icon.md`).
/// Never key: the Switcher keeps the keyboard.
final class WindowListPanel: NSPanel {
    private let content = FlippedView()
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
        title = "Window list"
        PanelBackground.install(content, in: self, cornerRadius: Metrics.cornerRadius, preGlass: RoundedFill.init)

        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.list)
        content.setAccessibilityLabel("Window list")
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
            content.addSubview(view)
        }
    }

    /// `anchor` is in screen coordinates: x is the selected icon's center, y the Switcher's bottom edge.
    func show(_ entry: AppRowEntry, selectedWindow: Int, icon: NSImage?, below anchor: NSPoint, on screen: NSScreen?) {
        let screenFrame = screen?.frame ?? NSRect(x: anchor.x - 200, y: 0, width: 400, height: anchor.y)
        let width = min(Metrics.width, screenFrame.width - 2 * Metrics.screenGutter)
        let listHeight = min(CGFloat(entry.windows.count) * Metrics.rowHeight, Metrics.maxListHeight)
        let height = 2 * Metrics.padding + Metrics.headerHeight + listHeight
        let x = min(
            max(anchor.x - width / 2, screenFrame.minX + Metrics.screenGutter),
            screenFrame.maxX - width - Metrics.screenGutter)
        let top = anchor.y - Metrics.gapBelowSwitcher
        setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: false)

        layoutHeader(entry, icon: icon, width: width)
        layoutRows(entry.windows, selected: selectedWindow, width: width, listHeight: listHeight)
        orderFront(nil)
    }

    private func layoutHeader(_ entry: AppRowEntry, icon: NSImage?, width: CGFloat) {
        let top = Metrics.padding + Metrics.headerTopPadding
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
            x: Metrics.padding, y: Metrics.padding + Metrics.headerHeight, width: listWidth,
            height: listHeight)
        let views = windows.enumerated().map { index, window in
            WindowRow(window, isSelected: index == selected)
        }
        rows.subviews = views
        for (index, row) in views.enumerated() {
            row.frame = NSRect(x: 0, y: CGFloat(index) * Metrics.rowHeight, width: listWidth, height: Metrics.rowHeight)
        }
        rows.frame = NSRect(x: 0, y: 0, width: listWidth, height: CGFloat(windows.count) * Metrics.rowHeight)
        content.setAccessibilityChildren(views)
        content.setAccessibilitySelectedChildren(views.filter(\.isSelected))
        if let selectedRow = views.first(where: \.isSelected) {
            selectedRow.scrollToVisible(selectedRow.bounds)
        }
    }
}

private final class WindowRow: NSView {
    let isSelected: Bool
    private let label: NSTextField
    private let tags: [WindowTag]

    init(_ window: WindowListEntry, isSelected: Bool) {
        self.isSelected = isSelected
        label = NSTextField(labelWithString: window.title)
        tags = window.labels.map { WindowTag($0.text, isSelected: isSelected) }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Metrics.rowCornerRadius
        if isSelected {
            layer?.backgroundColor = Palette.accent.cgColor
        }
        label.font = .systemFont(ofSize: Metrics.rowFontSize)
        label.textColor =
            isSelected ? .white : window.labels.contains(.minimized) ? Palette.muted : Palette.text
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityElement(false)
        for view in [label] + tags {
            addSubview(view)
        }

        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityRoleDescription("window")
        setAccessibilityLabel(([window.title] + window.labels.map(\.text)).joined(separator: ", "))
        setAccessibilitySelected(isSelected)
    }

    override func layout() {
        super.layout()
        var tagsMinX = bounds.width - Metrics.rowSidePadding
        for tag in tags.reversed() {
            let size = tag.fittingSize
            tagsMinX -= size.width
            tag.frame = NSRect(origin: NSPoint(x: tagsMinX, y: (bounds.height - size.height) / 2), size: size)
            tagsMinX -= Metrics.tagGap
        }
        let height = ceil(label.intrinsicContentSize.height)
        label.frame = NSRect(
            x: Metrics.rowSidePadding, y: (bounds.height - height) / 2,
            width: max(0, tagsMinX - Metrics.rowSidePadding), height: height)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

/// The prototype's `.tag`: a small outlined pill after the title.
private final class WindowTag: NSView {
    private let label: NSTextField
    private let isSelected: Bool

    override var wantsUpdateLayer: Bool { true }

    init(_ text: String, isSelected: Bool) {
        label = NSTextField(labelWithString: text)
        self.isSelected = isSelected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Metrics.tagCornerRadius
        layer?.borderWidth = 1
        label.font = .systemFont(ofSize: Metrics.tagFontSize)
        label.textColor = isSelected ? .white : Palette.muted
        label.setAccessibilityElement(false)
        addSubview(label)
        setAccessibilityElement(false)
    }

    /// Runs with the view's own appearance current, so the appearance-dependent border resolves against it.
    override func updateLayer() {
        layer?.borderColor = (isSelected ? NSColor(white: 1, alpha: 0.5) : Palette.border).cgColor
    }

    override var fittingSize: NSSize {
        let text = label.intrinsicContentSize
        return NSSize(width: ceil(text.width) + 2 * Metrics.tagSidePadding, height: ceil(text.height))
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: Metrics.tagSidePadding, dy: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

extension WindowLabel {
    fileprivate var text: String {
        switch self {
        case .minimized: "Minimized"
        case .hidden: "Hidden"
        }
    }
}

/// Before macOS 26: the prototype's near-opaque dark fill.
private final class RoundedFill: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Half a point in, so the 1 pt border is not clipped by the window's edge.
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: Metrics.cornerRadius, yRadius: Metrics.cornerRadius)
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
    /// The prototype's `gap: 8px` between title and tags, and its `.tag` style.
    static let tagGap: CGFloat = 8
    static let tagFontSize: CGFloat = 10
    static let tagSidePadding: CGFloat = 5
    static let tagCornerRadius: CGFloat = 5
    static let maxListHeight: CGFloat = 300
}
