import AppKit

extension NSView {
    func constraintsPinningEdges(to container: NSView) -> [NSLayoutConstraint] {
        [
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ]
    }
}
