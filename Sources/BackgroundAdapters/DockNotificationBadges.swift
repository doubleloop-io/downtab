import AppKit
import ApplicationServices

/// Reads the Notification badges off the Dock, the only process that knows every app's: an app's own Dock tile is
/// not readable from outside. Accessibility only, already granted; `AXStatusLabel` is undocumented, so when it goes
/// away every app just shows no badge.
public final class DockNotificationBadges: Sendable {
    private enum Source: Hashable {
        case dock
    }

    private let query = TimeboxedQuery<Source, [String: String]>()
    /// One Accessibility message per Dock item: a responsive Dock answers in a few tens of milliseconds.
    private static let deadline = Duration.seconds(2 * Double(Accessibility.messagingTimeout))

    public init() {}

    /// Keyed by bundle identifier: Dock items expose their bundle's location, which for system apps can differ
    /// from the running app's (Safari lives in a cryptex). A slow Dock leaves the last labels read.
    public func labelsByBundleIdentifier() async -> [String: String] {
        await query.run([.dock], within: Self.deadline) { _ in Self.readDock() }.answers[.dock] ?? [:]
    }

    private static func readDock() -> [String: String]? {
        guard
            let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        let lists = AXAttribute.copy(of: Accessibility.application(dock.processIdentifier), "AXChildren")
        var labels: [String: String] = [:]
        for list in lists as? [AXUIElement] ?? [] {
            for item in AXAttribute.copy(of: list, "AXChildren") as? [AXUIElement] ?? [] {
                // The label first: most items have none, and then their bundle is never read.
                guard let label = AXAttribute.string(of: item, "AXStatusLabel"), !label.isEmpty,
                    AXAttribute.string(of: item, "AXSubrole") == "AXApplicationDockItem",
                    let url = AXAttribute.copy(of: item, "AXURL") as? URL,
                    let bundleIdentifier = Bundle(url: url)?.bundleIdentifier
                else { continue }
                labels[bundleIdentifier] = label
            }
        }
        return labels
    }
}
