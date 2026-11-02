import AppKit
import SwitcherCore

/// Renders the core's displayed state and nothing else. Non-activating, so the Frontmost app keeps focus.
/// Look and metrics follow prototype variant A (`docs/prototype-switcher.html`).
final class SwitcherPanel: NSPanel {
    private let appRow = NSStackView()

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
        let views = displayed.appRow.enumerated().map { index, entry in
            AppTile(
                icon: icon(entry.id), name: entry.name, iconSize: iconSize, isSelected: index == displayed.selectedIndex
            )
        }
        appRow.setViews(views, in: .leading)
        appRow.setAccessibilitySelectedChildren(views.filter(\.isSelected))
        contentView?.layoutSubtreeIfNeeded()
        center(on: target, size: contentView?.fittingSize ?? .zero)
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        orderOut(nil)
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
            bottom: Metrics.panelPadding,
            right: Metrics.panelPadding
        )
        appRow.setAccessibilityElement(true)
        appRow.setAccessibilityRole(.list)
        appRow.setAccessibilityLabel("App row")
        appRow.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(appRow)
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

/// One App row entry: icon, and the app name shown only when selected. Every tile keeps the name's space,
/// so the row never moves when the selection does.
private final class AppTile: NSView {
    let isSelected: Bool

    // The name overhangs the tile, as in the prototype, so long names truncate later. Overridden because
    // AppKit turns clipping back on after init.
    override var clipsToBounds: Bool {
        get { false }
        set { _ = newValue }
    }

    init(icon: NSImage?, name: String, iconSize: CGFloat, isSelected: Bool) {
        self.isSelected = isSelected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Metrics.tileCornerRadius
        if isSelected {
            layer?.backgroundColor = Palette.selectedTile.cgColor
            layer?.borderWidth = 1
            layer?.borderColor = Palette.border.cgColor
        }

        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityRoleDescription("app")
        setAccessibilityLabel(name)
        setAccessibilitySelected(isSelected)

        let image = NSImageView()
        image.image = icon
        image.imageScaling = .scaleProportionallyUpOrDown
        image.setAccessibilityElement(false)

        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = Palette.text
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.alphaValue = isSelected ? 1 : 0
        label.setAccessibilityElement(false)

        for view in [image, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        let width = iconSize + Metrics.tileExtraWidth
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            image.widthAnchor.constraint(equalToConstant: iconSize),
            image.heightAnchor.constraint(equalToConstant: iconSize),
            image.centerXAnchor.constraint(equalTo: centerXAnchor),
            image.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.tileTopPadding),
            label.widthAnchor.constraint(equalToConstant: width + Metrics.nameOverhang),
            label.heightAnchor.constraint(equalToConstant: Metrics.nameHeight),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: image.bottomAnchor, constant: Metrics.nameGap),
            bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: Metrics.tileBottomPadding),
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
    static let tileTopPadding: CGFloat = 11
    static let tileBottomPadding: CGFloat = 8
    static let tileExtraWidth: CGFloat = 22
    static let nameGap: CGFloat = 4
    static let nameHeight: CGFloat = 18
    static let nameOverhang: CGFloat = 30
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
        let fitted = max(available / count - tileExtraWidth, minFittedIconSize)
        return floor(min(preferred, fitted))
    }
}

private enum Palette {
    static let border = NSColor(white: 1, alpha: 0.12)
    static let hudTint = NSColor(srgbRed: 30 / 255, green: 30 / 255, blue: 34 / 255, alpha: 0.8)
    static let selectedTile = NSColor(white: 1, alpha: 0.2)
    static let text = NSColor(srgbRed: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
}
