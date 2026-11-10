import AppKit
import SwitcherCore

/// Renders the core's displayed state and tells which tile is under the pointer. Non-activating, so the Frontmost
/// app keeps focus.
/// Look and metrics follow prototype variant A, with long names fitted as in variant E
/// (`docs/adr/assets/prototype-switcher.html`, `?names=below`).
final class SwitcherPanel: PointerPanel {
    private let appRow = NSStackView()
    private let selectedName = NSTextField(labelWithString: "")
    private let windowList = WindowListPanel()
    private var margins: [NSLayoutConstraint] = []
    private var spacing = RowSpacing(iconSize: Metrics.iconRange.upperBound)
    private var tiles: [AppTile] = []
    private var pointerMonitors: [Any] = []

    override var canBecomeKey: Bool { true }

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
        title = "Switcher"
        installContent()
    }

    override func attach(_ pointer: PointerInput) {
        super.attach(pointer)
        windowList.attach(pointer)
    }

    /// The whole tile is the target, not only its icon or its badge.
    override func pointerTarget(at location: NSPoint) -> PointerTarget? {
        tiles.firstIndex { $0.bounds.contains($0.convert(location, from: nil)) }.map(PointerTarget.app)
    }

    /// Where a click reaches the Switcher: none while it is closed or still transparent.
    var pointerFrames: [NSRect] {
        guard isVisible, alphaValue > 0 else { return [] }
        return windowList.isVisible ? [frame, windowList.frame] : [frame]
    }

    func show(_ displayed: DisplayedState, icon: (AppID) -> NSImage?) {
        // The display is chosen at opening: moving the selection never moves the panel to another display.
        let target = isVisible ? screen : SwitcherScreen.forOpening(frontmostApp: displayed.frontmostApp)
        let iconSize = Metrics.iconSize(screenWidth: target?.frame.width, tileCount: displayed.appRow.count)
        apply(RowSpacing(iconSize: iconSize))
        let selection: AppTile.Selection =
            switch displayed.level {
            case .app, .windowWithoutList: .selected
            case .window: .parentOfWindowList
            }
        let views = displayed.appRow.enumerated().map { index, entry in
            AppTile(
                icon: icon(entry.id), entry: entry, iconSize: iconSize, spacing: spacing,
                selection: index == displayed.selectedIndex ? selection : .unselected
            )
        }
        tiles = views
        appRow.setViews(views, in: .leading)
        appRow.setAccessibilitySelectedChildren(views.filter(\.isSelected))
        selectedName.stringValue = displayed.selectedEntry.name
        contentView?.layoutSubtreeIfNeeded()
        center(on: target, size: contentView?.fittingSize ?? .zero)
        // Tile frames are final only once the window has its new size.
        contentView?.layoutSubtreeIfNeeded()
        if let selectedTile = views.first(where: \.isSelected) {
            placeSelectedName(under: selectedTile)
        }
        // Before the show delay the Switcher is key but transparent: keys pressed then reach it, not the
        // Frontmost app, and a quick press never flashes it.
        alphaValue = displayed.isVisible ? 1 : 0
        makeKeyAndOrderFront(nil)
        followPointer()
        showWindowList(of: displayed, under: views.first(where: \.isSelected), icon: icon)
    }

    func hide() {
        stopFollowingPointer()
        tiles = []
        hideWindowList()
        orderOut(nil)
    }

    /// Downtab is never the active app, so its panels get no mouse moved events, not even through a tracking area:
    /// they go to the Frontmost app, where only a global monitor sees them.
    private func followPointer() {
        guard pointerMonitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.pointerMoved(event)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.pointerMoved(event)
            return event
        }
        pointerMonitors = [global, local].compactMap { $0 }
    }

    private func stopFollowingPointer() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors = []
    }

    private func pointerMoved(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        receivePointer(event, over: windowList.pointerTarget(atScreen: location) ?? pointerTarget(atScreen: location))
    }

    private func showWindowList(of displayed: DisplayedState, under tile: NSView?, icon: (AppID) -> NSImage?) {
        guard case .window(let selectedWindow) = displayed.level, let tile else {
            hideWindowList()
            return
        }
        let tileInWindow = tile.convert(tile.bounds, to: nil)
        let anchor = NSPoint(x: frame.minX + tileInWindow.midX, y: frame.minY)
        let entry = displayed.selectedEntry
        // A child window does not inherit its parent's transparency.
        windowList.alphaValue = alphaValue
        windowList.show(entry, selectedWindow: selectedWindow, icon: icon(entry.id), below: anchor, on: screen)
        if windowList.parent == nil {
            // A child window moves and closes with the Switcher.
            addChildWindow(windowList, ordered: .above)
        }
    }

    private func hideWindowList() {
        removeChildWindow(windowList)
        windowList.orderOut(nil)
    }

    /// Centered under the selected tile while it fits, otherwise pushed against the Switcher's edge. Placed by
    /// frame: Auto Layout would let a long name widen the Switcher, moving the row when the selection moves.
    private func placeSelectedName(under tile: NSView) {
        guard let content = selectedName.superview else { return }
        let tileFrame = tile.convert(tile.bounds, to: content)
        let padding = spacing.sidePadding
        let maxWidth = content.bounds.width - 2 * padding
        selectedName.sizeToFit()
        let width = min(ceil(selectedName.frame.width), maxWidth)
        let centeredX = tileFrame.midX - width / 2
        let x = min(max(centeredX, padding), content.bounds.width - padding - width)
        selectedName.frame = NSRect(
            x: x,
            y: tileFrame.minY - spacing.nameBand,
            width: width,
            height: Metrics.nameHeight
        )
    }

    private func installContent() {
        let content = NSView()
        appRow.orientation = .horizontal
        appRow.alignment = .top
        appRow.setAccessibilityElement(true)
        appRow.setAccessibilityRole(.list)
        appRow.setAccessibilityLabel("App row")
        appRow.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(appRow)

        selectedName.font = .systemFont(ofSize: Metrics.nameFontSize, weight: .medium)
        selectedName.textColor = Palette.text
        selectedName.alignment = .center
        // Truncating beats overflowing the Switcher, the only bound left on the name.
        selectedName.lineBreakMode = .byTruncatingTail
        // The App row's entries already carry the name.
        selectedName.setAccessibilityElement(false)
        selectedName.cell?.setAccessibilityElement(false)
        content.addSubview(selectedName)
        // Margins as constraints, not the stack's edge insets: inside system glass the vertical insets are lost.
        margins = [
            appRow.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: appRow.trailingAnchor),
            appRow.topAnchor.constraint(equalTo: content.topAnchor),
            content.bottomAnchor.constraint(equalTo: appRow.bottomAnchor),
        ]
        NSLayoutConstraint.activate(margins)
        apply(spacing)
        PanelBackground.install(
            content, in: self, cornerRadius: Metrics.panelCornerRadius, preGlass: Self.makeHUDBackground)
    }

    private func apply(_ spacing: RowSpacing) {
        self.spacing = spacing
        appRow.spacing = spacing.tileGap
        let constants = [
            spacing.sidePadding, spacing.sidePadding, spacing.topPadding, spacing.nameBand + spacing.bottomPadding,
        ]
        for (margin, constant) in zip(margins, constants) {
            margin.constant = constant
        }
    }

    private static func makeHUDBackground() -> NSView {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        // The layer's corner radius rounds the drawing only; the window server derives the window's shadow
        // from the material, which stays square unless masked.
        background.maskImage = roundedMask(radius: Metrics.panelCornerRadius)
        background.wantsLayer = true
        background.layer?.cornerRadius = Metrics.panelCornerRadius
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 1
        background.layer?.borderColor = Palette.border.cgColor
        // The HUD material alone lets bright windows show through; the prototype's panel stays dark.
        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = Palette.hudTint.cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(tint)
        NSLayoutConstraint.activate(tint.constraintsPinningEdges(to: background))
        return background
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = 2 * radius + 1
        let mask = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        mask.resizingMode = .stretch
        return mask
    }

    private func center(on screen: NSScreen?, size: NSSize) {
        guard let frame = screen?.frame else { return }
        setFrame(
            NSRect(
                x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height),
            display: true
        )
    }
}

private final class AppTile: NSView {
    enum Selection {
        case unselected
        case selected
        /// At Window level the selected tile dims, leaving the highlight to the selected window, and its Window count
        /// badge inverts.
        case parentOfWindowList
    }

    let isSelected: Bool

    init(icon: NSImage?, entry: AppRowEntry, iconSize: CGFloat, spacing: RowSpacing, selection: Selection) {
        isSelected = selection != .unselected
        super.init(frame: .zero)
        // The badges overhang the tile.
        clipsToBounds = false
        if isSelected {
            let highlight = TileHighlight(selection: selection, cornerRadius: spacing.tileCornerRadius)
            addSubview(highlight)
            NSLayoutConstraint.activate(highlight.constraintsPinningEdges(to: self))
        }

        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityRoleDescription("app")
        setAccessibilityLabel(entry.name)
        setAccessibilitySelected(isSelected)

        let image = NSImageView()
        image.image = icon
        image.imageScaling = .scaleProportionallyUpOrDown
        image.setAccessibilityElement(false)
        image.translatesAutoresizingMaskIntoConstraints = false
        addSubview(image)

        let side = iconSize + 2 * spacing.tileMargin
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side),
            image.widthAnchor.constraint(equalToConstant: iconSize),
            image.heightAnchor.constraint(equalToConstant: iconSize),
            image.centerXAnchor.constraint(equalTo: centerXAnchor),
            image.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        if let count = entry.windowCountBadge {
            let style: IconBadge.Style = selection == .parentOfWindowList ? .windowCountOfWindowList : .windowCount
            add(IconBadge("\(count)", iconSize: iconSize, style: style), on: image, at: .bottom, iconSize: iconSize)
        }
        if let label = entry.notificationBadge {
            add(IconBadge(label, iconSize: iconSize, style: .notification), on: image, at: .top, iconSize: iconSize)
        }
        let badges = [
            entry.windowCountBadge.map { "\($0) windows" },
            entry.notificationBadge.map { "notification badge \($0)" },
        ]
        let value = badges.compactMap(\.self).joined(separator: ", ")
        if !value.isEmpty { setAccessibilityValue(value) }
    }

    private enum BadgeCorner {
        /// The Notification badge, where the Dock puts it.
        case top
        /// The Window count badge.
        case bottom
    }

    /// Centered on the artwork's right corner: it covers the corner of the icon and may stick out of the tile.
    private func add(_ badge: IconBadge, on image: NSView, at corner: BadgeCorner, iconSize: CGFloat) {
        addSubview(badge)
        let inset = iconSize * Metrics.badgeCenterInsetRatio
        let centerY =
            switch corner {
            case .top: badge.centerYAnchor.constraint(equalTo: image.topAnchor, constant: inset)
            case .bottom: badge.centerYAnchor.constraint(equalTo: image.bottomAnchor, constant: -inset)
            }
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: image.trailingAnchor, constant: -inset), centerY,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

/// The selected tile's fill and border, in a view of its own beneath the icon and the badges: a layer draws its
/// border above its sublayers, which would cross the badges where they overhang the tile.
private final class TileHighlight: NSView {
    private let selection: AppTile.Selection

    override var wantsUpdateLayer: Bool { true }

    init(selection: AppTile.Selection, cornerRadius: CGFloat) {
        self.selection = selection
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = 1
    }

    /// Runs with the view's own appearance current, so the appearance-dependent colors resolve against it.
    override func updateLayer() {
        layer?.backgroundColor = (selection == .parentOfWindowList ? Palette.parentTile : Palette.selectedTile).cgColor
        layer?.borderColor = Palette.border.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

/// Spacing in and around the App row, following the native ⌘Tab's proportions (measured on macOS 27): it scales
/// with the icon. Linear in the icon size, which `Metrics.iconSize` relies on to fit the row.
private struct RowSpacing {
    /// Between the icon and the selected tile's edge, on every side.
    let tileMargin: CGFloat
    let tileGap: CGFloat
    let tileCornerRadius: CGFloat
    let sidePadding: CGFloat
    let topPadding: CGFloat
    /// Below the selected name.
    let bottomPadding: CGFloat

    /// The room the Switcher grows at the bottom for the selected name.
    var nameBand: CGFloat { Metrics.nameGap + Metrics.nameHeight }

    init(iconSize: CGFloat) {
        tileMargin = 0.04 * iconSize - 1.5
        tileGap = 0.08 * iconSize
        tileCornerRadius = 0.22 * iconSize
        sidePadding = 0.3 * iconSize
        topPadding = 0.3 * iconSize
        bottomPadding = 0.1 * iconSize
    }

    func rowWidth(iconSize: CGFloat, tileCount: Int) -> CGFloat {
        let count = CGFloat(tileCount)
        return 2 * sidePadding + count * (iconSize + 2 * tileMargin) + (count - 1) * tileGap
    }
}

private enum Metrics {
    static let panelCornerRadius: CGFloat = 28
    /// From the icon box's corner to the badge's center: where the artwork's corner is, past the box's transparent
    /// margin.
    static let badgeCenterInsetRatio: CGFloat = 0.1
    static let nameGap: CGFloat = 4
    static let nameHeight: CGFloat = 18
    static let nameFontSize: CGFloat = 13
    /// The prototype's `clamp(56px, 8.6vw, 96px)`.
    static let iconRange: ClosedRange<CGFloat> = 56...96
    static let iconScreenRatio: CGFloat = 0.086
    /// Share of the screen width the panel may take before icons shrink to fit.
    static let maxPanelScreenRatio: CGFloat = 0.95
    /// Below this the icons are unreadable: past it the panel overflows the screen instead.
    static let minFittedIconSize: CGFloat = 24

    static func iconSize(screenWidth: CGFloat?, tileCount: Int) -> CGFloat {
        guard let screenWidth, tileCount > 0 else { return iconRange.upperBound }
        let preferred = min(max(screenWidth * iconScreenRatio, iconRange.lowerBound), iconRange.upperBound)
        // The row's width is linear in the icon size: its value at 0 and its slope give the fitting size.
        let fixedWidth = RowSpacing(iconSize: 0).rowWidth(iconSize: 0, tileCount: tileCount)
        let widthPerPoint = RowSpacing(iconSize: 1).rowWidth(iconSize: 1, tileCount: tileCount) - fixedWidth
        let available = screenWidth * maxPanelScreenRatio - fixedWidth
        let fitted = max(available / widthPerPoint, minFittedIconSize)
        return floor(min(preferred, fitted))
    }
}
