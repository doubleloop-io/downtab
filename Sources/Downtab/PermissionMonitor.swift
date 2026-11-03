import BackgroundAdapters
import SwitcherCore

/// Reports when the Accessibility permission is granted or revoked, so Downtab never needs a restart for it.
final class PermissionMonitor {
    private static let pollInterval = Duration.seconds(1)
    private var watch = PermissionWatch()
    private var polling: Task<Void, Never>?

    var isGranted: Bool { watch.isGranted }

    func start(onChange: @escaping (PermissionWatch.Change) -> Void) {
        check(onChange)
        polling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                self?.check(onChange)
            }
        }
    }

    private func check(_ onChange: (PermissionWatch.Change) -> Void) {
        if let change = watch.observe(isGranted: AccessibilityPermission.isGranted) {
            onChange(change)
        }
    }
}
