import AppKit

/// Recalls a downloaded Update the user has not installed: its version, its notes, `Restart to Update` and `Later`.
/// `Later` and closing do the same: the Update stays pending and the menu bar keeps signalling it.
final class UpdateWindow: NSWindow {
    private enum Layout {
        static let margin: CGFloat = 20
        static let width: CGFloat = 460
        static let notesHeight: CGFloat = 220
        static let spacing: CGFloat = 12
    }

    private let onRestart: () -> Void

    init(version: String, runningVersion: String?, notes: NSAttributedString?, onRestart: @escaping () -> Void) {
        self.onRestart = onRestart
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Downtab Update"
        isReleasedWhenClosed = false
        let heading = NSTextField(labelWithString: "Downtab \(version) is ready to install")
        heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        let detail = NSTextField(
            wrappingLabelWithString: (runningVersion.map { "You have \($0). " } ?? "")
                + "The update installs when you restart Downtab.")
        detail.textColor = .secondaryLabelColor
        detail.preferredMaxLayoutWidth = Layout.width
        var rows: [NSView] = [heading, detail]
        if let notes {
            rows.append(Self.notesView(notes))
        }
        rows.append(makeButtons())
        contentView = Self.column(rows)
        center()
    }

    @objc private func restart() {
        close()
        onRestart()
    }

    @objc private func later() {
        close()
    }

    private func makeButtons() -> NSView {
        let restart = NSButton(title: "Restart to Update", target: self, action: #selector(restart))
        restart.keyEquivalent = "\r"
        let later = NSButton(title: "Later", target: self, action: #selector(later))
        later.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [later, restart])
        buttons.spacing = Layout.spacing
        return buttons
    }

    private static func notesView(_ notes: NSAttributedString) -> NSView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: Layout.width),
            scroll.heightAnchor.constraint(equalToConstant: Layout.notesHeight),
        ])
        if let text = scroll.documentView as? NSTextView {
            text.isEditable = false
            text.textContainerInset = NSSize(width: 6, height: 6)
            text.textStorage?.setAttributedString(notes)
            text.setAccessibilityLabel("Release notes")
        }
        return scroll
    }

    private static func column(_ rows: [NSView]) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Layout.margin, left: Layout.margin, bottom: Layout.margin, right: Layout.margin)
        if let buttons = rows.last {
            stack.setCustomSpacing(Layout.margin, after: rows[rows.count - 2])
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -Layout.margin).isActive = true
        }
        return stack
    }
}

/// An appcast item's notes as text for `UpdateWindow`. The release pipeline writes the changelog section as Markdown:
/// headings and list items get their own lines, bold, italics, code and links render inline.
enum ReleaseNotes {
    private static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

    static func render(_ text: String?, format: String?) -> NSAttributedString? {
        guard let text, !text.isEmpty else { return nil }
        guard format == "markdown" else {
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        let rendered = NSMutableAttributedString()
        for line in text.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines) {
            rendered.append(renderLine(line))
            rendered.append(NSAttributedString(string: "\n"))
        }
        return rendered
    }

    private static func renderLine(_ line: String) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            let title = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            return inline(title, base: .boldSystemFont(ofSize: NSFont.systemFontSize + 1))
        }
        for marker in ["- ", "* "] where trimmed.hasPrefix(marker) {
            let item = NSMutableAttributedString(string: "•\t", attributes: [.font: font])
            item.append(inline(String(trimmed.dropFirst(marker.count)), base: font))
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = 14
            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 14)]
            item.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: item.length))
            return item
        }
        return inline(line, base: font)
    }

    private static func inline(_ text: String, base: NSFont) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        let result = NSMutableAttributedString()
        for run in parsed.runs {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: styled(base, run.inlinePresentationIntent), .foregroundColor: NSColor.labelColor,
            ]
            if let link = run.link {
                attributes[.link] = link
            }
            result.append(NSAttributedString(string: String(parsed[run.range].characters), attributes: attributes))
        }
        return result
    }

    private static func styled(_ font: NSFont, _ intent: InlinePresentationIntent?) -> NSFont {
        guard let intent else { return font }
        if intent.contains(.code) {
            return .monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        }
        var traits: NSFontDescriptor.SymbolicTraits = font.fontDescriptor.symbolicTraits
        if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
        if intent.contains(.emphasized) { traits.insert(.italic) }
        return NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits), size: font.pointSize) ?? font
    }
}
