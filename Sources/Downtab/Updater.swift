import AppKit
import Foundation
import Sparkle
import SwitcherCore
import os

/// Downtab's updates through Sparkle: checks daily, downloads in the background, installs on quit. Downtab rarely
/// quits, so a downloaded Update is also signalled in the menu bar, installable at once, and recalled by a window
/// every 7 days (`UpdateReminder`).
final class Updater: NSObject, SPUUpdaterDelegate {
    /// While an Update waits, Sparkle runs no further checks, so the reminder needs its own clock. Wall-clock dates,
    /// compared on each tick: a sleeping Mac catches up on the first tick after waking.
    private static let reminderTick: Duration = .seconds(60 * 60)

    private let logger = Logger(subsystem: "io.doubleloop.downtab", category: "update")
    private let store = UpdateReminderStore()
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    private var pending: (item: SUAppcastItem, install: () -> Void)?
    private var reminderTicks: Task<Void, Never>?
    private var window: UpdateWindow?
    private var onPending: (String) -> Void = { _ in }

    /// `onPending` gets the version of each Update downloaded and ready to install.
    func start(onPending: @escaping (String) -> Void) {
        self.onPending = onPending
        if let runningBuild = Self.runningBuild {
            store.update { $0.launched(runningBuild: runningBuild) }
        }
        do {
            try controller.updater.start()
            // Development launches (`make run`, `make smoke`) pass `-SUEnableAutomaticChecks NO`: Sparkle reads the
            // argument domain, so they never touch the feed on their own.
            let automatic = controller.updater.automaticallyChecksForUpdates ? "on" : "off"
            logger.notice("updater started, automatic checks \(automatic, privacy: .public)")
        } catch {
            // Outside the app bundle (`swift run`) Sparkle has no feed or key: Downtab runs without updates.
            logger.error("updater not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// While an Update waits, Sparkle refuses a new check: the Update's own window answers instead.
    func checkForUpdates() {
        if pending != nil {
            showWindow()
            return
        }
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    /// Installs the pending Update and relaunches Downtab, with no further UI.
    func installNow() {
        pending?.install()
    }

    func updater(
        _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        logger.notice("update \(item.displayVersionString, privacy: .public) downloaded, installs on quit")
        pending = (item, immediateInstallHandler)
        let now = Date.now
        store.update { $0.signalled(build: Int(item.versionString) ?? 0, at: now) }
        onPending(item.displayVersionString)
        startReminderTicks()
        // Taking control: Sparkle shows no prompts of its own, the reminder window is Downtab's.
        return true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        logger.error("update check failed: \(error.localizedDescription, privacy: .public)")
    }

    private func startReminderTicks() {
        reminderTicks?.cancel()
        reminderTicks = Task { [weak self] in
            while !Task.isCancelled {
                self?.remindIfDue()
                try? await Task.sleep(for: Self.reminderTick)
            }
        }
    }

    private func remindIfDue() {
        let now = Date.now
        guard pending != nil, store.load().isDue(at: now) else { return }
        logger.notice("update pending for 7 days or more: showing the reminder")
        store.update { $0.reminded(at: now) }
        showWindow()
    }

    private func showWindow() {
        guard let pending else { return }
        window?.close()
        let window = UpdateWindow(
            version: pending.item.displayVersionString,
            runningVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            notes: ReleaseNotes.render(pending.item.itemDescription, format: pending.item.itemDescriptionFormat),
            onRestart: { [weak self] in self?.installNow() })
        self.window = window
        // Activation is only a request since macOS 14: the active app may keep focus, above all when the reminder
        // opens from a timer. Ordering front regardless still shows the window above it.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static var runningBuild: Int? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap { Int($0) }
    }
}

/// The `UpdateReminder` in `UserDefaults`, read on every use so a `defaults write` (manual checklist) takes effect.
private struct UpdateReminderStore {
    private static let firstSignalledKey = "updateFirstSignalled"
    private static let lastRemindedKey = "updateLastReminded"
    private static let signalledBuildKey = "updateSignalledBuild"

    private let defaults = UserDefaults.standard

    func load() -> UpdateReminder {
        UpdateReminder(
            firstSignalled: defaults.object(forKey: Self.firstSignalledKey) as? Date,
            lastReminded: defaults.object(forKey: Self.lastRemindedKey) as? Date,
            signalledBuild: defaults.object(forKey: Self.signalledBuildKey) as? Int)
    }

    func update(_ change: (inout UpdateReminder) -> Void) {
        var reminder = load()
        change(&reminder)
        defaults.set(reminder.firstSignalled, forKey: Self.firstSignalledKey)
        defaults.set(reminder.lastReminded, forKey: Self.lastRemindedKey)
        defaults.set(reminder.signalledBuild, forKey: Self.signalledBuildKey)
    }
}
