import ServiceManagement
import os

struct LaunchAtLogin {
    enum Status {
        case on
        case off
        /// The user turned the login item off in System Settings: only they can turn it back on there.
        case needsApproval
    }

    private let store = SettingsStore()
    private let service = SMAppService.mainApp
    private let logger = Logger(subsystem: "io.github.iacoware.downtab", category: "login")

    var isWanted: Bool { store.launchAtLogin() }

    var status: Status {
        switch service.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        default: .off
        }
    }

    /// Called at every launch, so the login item exists from the first one.
    func applyStored() {
        apply(store.launchAtLogin())
    }

    func set(_ wanted: Bool) {
        store.save(launchAtLogin: wanted)
        apply(wanted)
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // Registering again while approval is pending would not override the user's choice in System Settings.
    private func apply(_ wanted: Bool) {
        do {
            switch (wanted, service.status) {
            case (true, .notRegistered), (true, .notFound):
                try service.register()
            case (false, .enabled), (false, .requiresApproval):
                try service.unregister()
            default:
                break
            }
        } catch {
            logger.error("cannot turn launch at login \(wanted ? "on" : "off", privacy: .public): \(error)")
        }
    }
}
