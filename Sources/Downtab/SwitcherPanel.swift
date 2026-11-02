import AppKit
import SwitcherCore

/// Renders the core's displayed state and nothing else. Non-activating, so the Frontmost app keeps focus.
final class SwitcherPanel: NSPanel {
    private static let iconSize: CGFloat = 64
    private static let tilePadding: CGFloat = 8
    private static let margin: CGFloat = 16

    private let tiles = NSStackView()
    private let nameLabel = NSTextField(labelWithString: "")

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
        contentView = makeContent()
    }

    func show(_ displayed: DisplayedState, icon: (AppID) -> NSImage?) {
        tiles.setViews(
            displayed.appRow.enumerated().map { index, entry in
                makeTile(icon: icon(entry.id), name: entry.name, isSelected: index == displayed.selectedIndex)
            },
            in: .leading
        )
        nameLabel.stringValue = displayed.selectedEntry.name
        contentView?.layoutSubtreeIfNeeded()
        centerOnPointerScreen(size: contentView?.fittingSize ?? .zero)
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
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true

        tiles.orientation = .horizontal
        tiles.spacing = 4
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.alignment = .center

        let column = NSStackView(views: [tiles, nameLabel])
        column.orientation = .vertical
        column.spacing = 8
        column.edgeInsets = NSEdgeInsets(
            top: Self.margin,
            left: Self.margin,
            bottom: Self.margin,
            right: Self.margin
        )
        column.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            column.topAnchor.constraint(equalTo: background.topAnchor),
            column.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        return background
    }

    private func makeTile(icon: NSImage?, name: String, isSelected: Bool) -> NSView {
        let image = NSImageView()
        image.image = icon
        image.imageScaling = .scaleProportionallyUpOrDown
        image.setAccessibilityLabel(name)
        image.translatesAutoresizingMaskIntoConstraints = false

        let tile = NSView()
        tile.wantsLayer = true
        tile.layer?.cornerRadius = 10
        tile.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.cgColor : nil
        tile.addSubview(image)
        let side = Self.iconSize + 2 * Self.tilePadding
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: side),
            tile.heightAnchor.constraint(equalToConstant: side),
            image.widthAnchor.constraint(equalToConstant: Self.iconSize),
            image.heightAnchor.constraint(equalToConstant: Self.iconSize),
            image.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
        ])
        return tile
    }

    private func centerOnPointerScreen(size: NSSize) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        setFrame(
            NSRect(
                x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height),
            display: true
        )
    }
}
