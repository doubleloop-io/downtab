# Updates with Sparkle 2

Downtab updates itself with [Sparkle 2](https://sparkle-project.org), its first runtime dependency, pinned exactly in `Package.swift`. It checks the Appcast every day, downloads an Update in the background and installs it on quit. Since Downtab rarely quits, a downloaded Update is also signalled by a dot on the menu bar icon and `Restart to Update X.Y.Z` in the menu, which installs it at once, and recalled by a window 7 days after the first signal, then every 7 days. The Appcast and the DMG are release assets: publishing a release ships the Update.

## Context

Until 0.5.0 Downtab only asked GitHub for the latest release's tag and showed `Update Available: X.Y.Z…`, which opened the website: every Update meant downloading the DMG and replacing the app by hand. Decided in #67, validated by the spike in #69.

## Considered options

- **A home-made updater.** Rejected: atomic replacement, permissions, quarantine and download verification are what Sparkle already solves.
- **The Mac App Store.** Rejected: ADR 0001 rules it out (private APIs, no sandbox).
- **A Homebrew cask.** Rejected as the update channel: it could only ever be a complement.
- **The Appcast on the website.** Rejected: a release would also need a website deploy. `SUFeedURL` is `releases/latest/download/appcast.xml`, which GitHub redirects to the latest release's asset.
- **Install on quit only.** Rejected: Downtab runs for weeks, so the Update would wait just as long.
- **Ask before downloading, or show a popup when an Update is ready.** Rejected: an app switcher should not interrupt; the badge is enough until the Update has waited 7 days.
- **Sparkle's own window for the 7-day reminder.** Rejected: Downtab takes control of the install (`willInstallUpdateOnQuit` returns `true`, to keep the block behind `Restart to Update`), and from then on Sparkle refuses `checkForUpdates()` (`sessionInProgress`), so it shows no window. Returning `false` would bring Sparkle's window and its own 7-day reminder back, but that reminder was never observed in the spike and would not keep the date of the first signal across newer Updates.

## Consequences

- `Updater` (main actor: Sparkle's delegate protocols are `NS_SWIFT_UI_ACTOR`) owns Sparkle and the reminder window; `UpdateReminder` in `SwitcherCore` holds the 7-day rule, stored in `UserDefaults` as `updateFirstSignalled`, `updateLastReminded` and `updateSignalledBuild`. Launching the signalled build, or a later one, forgets them.
- While an Update waits, Sparkle runs no further checks: a newer release published meanwhile is seen only after the next launch. `Check for Updates…` then shows Downtab's window for the pending Update instead of Sparkle's.
- Any termination installs a downloaded Update, `kill -9` included, but only `Restart to Update` relaunches: after `Quit Downtab` the Update takes effect at the next launch or login.
- An Update Sparkle cannot install silently (a `Downtab.app` the user cannot write) comes with no immediate-install block, so the badge and `Restart to Update` cannot stand in for it: on a scheduled check Sparkle shows its own alert (`supportsGentleScheduledUpdateReminders`), and `Updater` brings it in front of the active app's windows once it appears (#73). No badge for it: the alert already offers the install.
- Sparkle compares `CFBundleVersion`, the commit count on main (`scripts/stamp-version.sh`). Development builds carry a count at least as high as the latest release, so they are never offered one; `make run` and `make smoke` also pass `-SUEnableAutomaticChecks NO`, which Sparkle reads from the argument domain, so they never fetch the Appcast on their own.
- `make bundle` copies `Sparkle.framework` into `Contents/Frameworks`, drops its XPC services (Downtab is not sandboxed) and signs inside out, never `--deep`. Self-signed builds carry `com.apple.security.cs.disable-library-validation`: their certificate has no Team ID, so library validation would refuse the framework.
- An Info.plist without `SUPublicEDKey`, or with a wrong one, makes Sparkle refuse every Update. Losing the private key (README, Distribution) means installed copies can never update again.
- Installs up to 0.5.0 keep the old check and update by hand once.
