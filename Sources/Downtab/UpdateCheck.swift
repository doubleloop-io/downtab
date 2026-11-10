import BackgroundAdapters
import Foundation
import os

/// Looks for a newer Downtab release shortly after launch, then every day while running. Never sends more than
/// one request per hour, relaunches included. A failed check changes nothing: the next scheduled one retries.
final class UpdateCheck {
    static let downloadPage = URL(string: "https://downtab.doubleloop.io/")

    private static let launchDelay: Duration = .seconds(10)
    private static let interval: Duration = .seconds(24 * 60 * 60)
    private static let minimumGap: TimeInterval = 60 * 60
    private static let lastCheckKey = "lastUpdateCheck"

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "io.doubleloop.downtab", category: "update")

    /// `report` gets the newer release after each successful check, or `nil` when the running app is the latest.
    func start(report: @escaping (ReleaseVersion?) -> Void) {
        guard let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let running = ReleaseVersion(bundleVersion)
        else {
            logger.info("update check off: no X.Y.Z bundle version (running outside the app bundle?)")
            return
        }
        Task {
            try? await Task.sleep(for: Self.launchDelay)
            while true {
                await waitOutMinimumGap()
                defaults.set(Date.now, forKey: Self.lastCheckKey)
                if let latest = await LatestRelease.fetch() {
                    report(latest > running ? latest : nil)
                }
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    private func waitOutMinimumGap() async {
        guard let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date else { return }
        // Capped: a clock set back must not postpone every later check.
        let remaining = min(lastCheck.addingTimeInterval(Self.minimumGap).timeIntervalSinceNow, Self.minimumGap)
        guard remaining > 0 else { return }
        logger.notice("last update check less than an hour ago: next one in \(Int(remaining))s")
        try? await Task.sleep(for: .seconds(remaining))
    }
}
