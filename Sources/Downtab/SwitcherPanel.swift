import AppKit
import SwitcherCore

/// Renders the core's displayed state and nothing else. Non-activating, so the Frontmost app keeps focus.
/// Look and metrics follow prototype variant A, with long names fitted as in variant E
/// (`docs/adr/assets/prototype-switcher.html`, `?names=below`).
final class SwitcherPanel: NSPanel {
    private let appRow = NSStackView()
    private let selectedName = NSTextField(labelWithString: "")
    private let windowList = WindowListPanel()
    private var margins: [NSLayoutConstraint] = []
    private var spacing = RowSpacing(iconSize: Metrics.iconRange.upperBound)

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
        showWindowList(of: displayed, under: views.first(where: \.isSelected), icon: icon)
    }

    func hide() {
        hideWindowList()
        orderOut(nil)
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
        /// At Window level the selected tile dims, leaving the highlight to the selected window, and its badge
        /// inverts.
        case parentOfWindowList
    }

    let isSelected: Bool
    private let selection: Selection

    override var wantsUpdateLayer: Bool { true }

    init(icon: NSImage?, entry: AppRowEntry, iconSize: CGFloat, spacing: RowSpacing, selection: Selection) {
        isSelected = selection != .unselected
        self.selection = selection
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = spacing.tileCornerRadius
        if isSelected {
            layer?.borderWidth = 1
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
            setAccessibilityValue("\(count) windows")
            addBadge(
                count, iconSize: iconSize, tileMargin: spacing.tileMargin, isInverted: selection == .parentOfWindowList)
        }
    }

    /// Runs with the view's own appearance current, so the appearance-dependent colors resolve against it.
    override func updateLayer() {
        guard isSelected else { return }
        layer?.backgroundColor = (selection == .parentOfWindowList ? Palette.parentTile : Palette.selectedTile).cgColor
        layer?.borderColor = Palette.border.cgColor
    }

    /// Centered on the artwork's corner, inside the icon box past its transparent margin.
    private func addBadge(_ count: Int, iconSize: CGFloat, tileMargin: CGFloat, isInverted: Bool) {
        let badge = WindowCountBadge(
            count: count, diameter: Metrics.badgeDiameter(iconSize: iconSize), isInverted: isInverted)
        addSubview(badge)
        let offset = tileMargin + iconSize * Metrics.badgeCenterIconRatio
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: leadingAnchor, constant: offset),
            badge.centerYAnchor.constraint(equalTo: topAnchor, constant: offset),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

/// Style `cerchio` of the prototype: a light disc with an accent ring and the count; inverted, an accent disc with a
/// white ring.
private final class WindowCountBadge: NSView {
    init(count: Int, diameter: CGFloat, isInverted: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
        wantsLayer = true
        layer?.backgroundColor = (isInverted ? Palette.accent : Palette.badgeFill).cgColor
        layer?.cornerRadius = diameter / 2
        // A layer border is drawn inside the bounds, like the prototype's inset ring.
        layer?.borderWidth = Metrics.badgeRing(diameter: diameter)
        layer?.borderColor = (isInverted ? NSColor.white : Palette.accent).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = Metrics.badgeShadowOpacity
        layer?.shadowRadius = Metrics.badgeShadowRadius
        layer?.shadowOffset = Metrics.badgeShadowOffset

        let text = "\(count)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: diameter * Metrics.badgeFontRatio, weight: .semibold)
        // Measured on the glyphs, not the NSTextField, whose own inset would turn 1–2 digits into a pill.
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let width = max(diameter, textWidth + 2 * diameter * Metrics.badgePaddingRatio)

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = isInverted ? .white : Palette.badgeText
        label.alignment = .center
        label.setAccessibilityElement(false)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: diameter),
            widthAnchor.constraint(equalToConstant: width),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

/// Spacing in and around the App row, following the native ⌘Tab's proportions (measured on macOS 27): it scales
/// with the icon. Linear in the icon size, which `Metrics.iconSize` relies on to fit the row.
private struct RowSpacing {
    /// Between the icon and the selected tile's edge, on every side: just enough for the Window count badge, which
    /// straddles the icon's corner, to stay inside the tile.
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
        tileMargin = 0.06 * iconSize + 2
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
    /// The prototype's `--badge: calc(var(--icon) * 0.3)`.
    static let badgeIconRatio: CGFloat = 0.3
    /// Variant E: with the tile wrapping only the icon, the badge sits at 86% of the icon, keeping a margin.
    static let badgeCenterIconRatio: CGFloat = 0.86
    /// Below this the count is unreadable, however small the icons.
    static let minBadgeDiameter: CGFloat = 16
    /// Per side, between the count and the badge's edge: 1–2 digits stay a circle, 3+ grow into a pill.
    static let badgePaddingRatio: CGFloat = 0.15
    static let badgeRingRatio: CGFloat = 0.1
    static let badgeRingRange: ClosedRange<CGFloat> = 1...3
    static let badgeFontRatio: CGFloat = 0.5
    /// The prototype's `0 2px 6px rgba(0, 0, 0, 0.35)`.
    static let badgeShadowOpacity: Float = 0.35
    static let badgeShadowRadius: CGFloat = 3
    static let badgeShadowOffset = CGSize(width: 0, height: -2)
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

    static func badgeDiameter(iconSize: CGFloat) -> CGFloat {
        max(iconSize * badgeIconRatio, minBadgeDiameter)
    }

    /// Proportional, so it never overwhelms the count on small badges.
    static func badgeRing(diameter: CGFloat) -> CGFloat {
        min(max(diameter * badgeRingRatio, badgeRingRange.lowerBound), badgeRingRange.upperBound)
    }

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
