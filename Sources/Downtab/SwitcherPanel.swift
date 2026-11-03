import AppKit
import SwitcherCore

/// Renders the core's displayed state and nothing else. Non-activating, so the Frontmost app keeps focus.
/// Look and metrics follow prototype variant A, with long names fitted as in variant E
/// (`docs/prototype-switcher.html`, `?names=below`).
final class SwitcherPanel: NSPanel {
    private let appRow = NSStackView()
    private let selectedName = NSTextField(labelWithString: "")
    private let windowList = WindowListPanel()

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
        // The prototype is a dark HUD whatever the system appearance.
        appearance = NSAppearance(named: .darkAqua)
        title = "Switcher"
        contentView = makeContent()
    }

    func show(_ displayed: DisplayedState, icon: (AppID) -> NSImage?) {
        // The display is chosen at opening: moving the selection never moves the panel to another display.
        let target = isVisible ? screen : Self.pointerScreen()
        let iconSize = Metrics.iconSize(screenWidth: target?.frame.width, tileCount: displayed.appRow.count)
        let selection: AppTile.Selection =
            switch displayed.level {
            case .app, .windowWithoutList: .selected
            case .window: .parentOfWindowList
            }
        let views = displayed.appRow.enumerated().map { index, entry in
            AppTile(
                icon: icon(entry.id), entry: entry, iconSize: iconSize,
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
        guard let content = contentView else { return }
        let tileFrame = tile.convert(tile.bounds, to: content)
        let maxWidth = content.bounds.width - 2 * Metrics.panelPadding
        selectedName.sizeToFit()
        let width = min(ceil(selectedName.frame.width), maxWidth)
        let centeredX = tileFrame.midX - width / 2
        let x = min(max(centeredX, Metrics.panelPadding), content.bounds.width - Metrics.panelPadding - width)
        selectedName.frame = NSRect(
            x: x,
            y: tileFrame.minY - Metrics.nameBand,
            width: width,
            height: Metrics.nameHeight
        )
    }

    private func makeContent() -> NSView {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
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

        appRow.orientation = .horizontal
        appRow.alignment = .top
        appRow.spacing = Metrics.tileGap
        appRow.edgeInsets = NSEdgeInsets(
            top: Metrics.panelPadding,
            left: Metrics.panelPadding,
            bottom: Metrics.nameBand + Metrics.panelPadding,
            right: Metrics.panelPadding
        )
        appRow.setAccessibilityElement(true)
        appRow.setAccessibilityRole(.list)
        appRow.setAccessibilityLabel("App row")
        appRow.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(appRow)

        selectedName.font = .systemFont(ofSize: Metrics.nameFontSize, weight: .medium)
        selectedName.textColor = Palette.text
        selectedName.alignment = .center
        // Truncating beats overflowing the Switcher, the only bound left on the name.
        selectedName.lineBreakMode = .byTruncatingTail
        // The App row's entries already carry the name.
        selectedName.setAccessibilityElement(false)
        selectedName.cell?.setAccessibilityElement(false)
        background.addSubview(selectedName)
        NSLayoutConstraint.activate(
            Self.edges(of: tint, pinnedTo: background) + Self.edges(of: appRow, pinnedTo: background))
        return background
    }

    private static func edges(of view: NSView, pinnedTo container: NSView) -> [NSLayoutConstraint] {
        [
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ]
    }

    private static func pointerScreen() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
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

    init(icon: NSImage?, entry: AppRowEntry, iconSize: CGFloat, selection: Selection) {
        isSelected = selection != .unselected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Metrics.tileCornerRadius
        if isSelected {
            layer?.backgroundColor =
                (selection == .parentOfWindowList ? Palette.parentTile : Palette.selectedTile).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = Palette.border.cgColor
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

        let side = iconSize + 2 * Metrics.tileMargin
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
            addBadge(count, iconSize: iconSize, isInverted: selection == .parentOfWindowList)
        }
    }

    /// Centered on the artwork's corner, inside the icon box past its transparent margin.
    private func addBadge(_ count: Int, iconSize: CGFloat, isInverted: Bool) {
        let badge = WindowCountBadge(
            count: count, diameter: iconSize * Metrics.badgeIconRatio, isInverted: isInverted)
        addSubview(badge)
        let offset = Metrics.tileMargin + iconSize * Metrics.badgeCenterIconRatio
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
        layer?.borderWidth = Metrics.badgeRing
        layer?.borderColor = (isInverted ? NSColor.white : Palette.accent).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = Metrics.badgeShadowOpacity
        layer?.shadowRadius = Metrics.badgeShadowRadius
        layer?.shadowOffset = Metrics.badgeShadowOffset

        let label = NSTextField(labelWithString: "\(count)")
        label.font = .monospacedDigitSystemFont(ofSize: diameter * Metrics.badgeFontRatio, weight: .semibold)
        label.textColor = isInverted ? .white : Palette.badgeText
        label.alignment = .center
        label.setAccessibilityElement(false)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: diameter),
            widthAnchor.constraint(greaterThanOrEqualToConstant: diameter),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metrics.badgePadding),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metrics.badgePadding),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }
}

private enum Metrics {
    static let panelPadding: CGFloat = 14
    static let panelCornerRadius: CGFloat = 28
    static let tileGap: CGFloat = 6
    static let tileCornerRadius: CGFloat = 20
    /// Between the icon and the selected tile's edge, on every side.
    static let tileMargin: CGFloat = 14
    /// The prototype's `--badge: calc(var(--icon) * 0.3)`.
    static let badgeIconRatio: CGFloat = 0.3
    /// Variant E: with the tile wrapping only the icon, the badge sits at 86% of the icon, keeping a margin.
    static let badgeCenterIconRatio: CGFloat = 0.86
    static let badgeRing: CGFloat = 3
    static let badgePadding: CGFloat = 4
    static let badgeFontRatio: CGFloat = 0.5
    /// The prototype's `0 2px 6px rgba(0, 0, 0, 0.35)`.
    static let badgeShadowOpacity: Float = 0.35
    static let badgeShadowRadius: CGFloat = 3
    static let badgeShadowOffset = CGSize(width: 0, height: -2)
    static let nameGap: CGFloat = 8
    static let nameHeight: CGFloat = 18
    static let nameFontSize: CGFloat = 13
    /// The room the Switcher grows at the bottom for the selected name.
    static let nameBand = nameGap + nameHeight
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
        let count = CGFloat(tileCount)
        let available = screenWidth * maxPanelScreenRatio - 2 * panelPadding - (count - 1) * tileGap
        let fitted = max(available / count - 2 * tileMargin, minFittedIconSize)
        return floor(min(preferred, fitted))
    }
}
