# Changelog

User-facing changes to Downtab. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow `VERSION`.

## [Unreleased]

### Added

- Install Downtab with Homebrew: `brew install --cask doubleloop-io/tap/downtab`. It still updates itself; `brew uninstall` quits it and turns native ⌘Tab back on.

### Changed

- Switcher: with a Window list open, the App shortcut (⌥Tab by default, ⇧ to go back) now moves to the next app like `→`: it stays at Window level and opens that app's Window list, instead of closing the list and going back to App level.

## [0.6.0] - 2026-11-18

### Added

- Downtab updates itself: it checks for a new version every day, downloads it in the background and installs it when Downtab quits. Meanwhile a dot on the menu bar icon and `Restart to Update X.Y.Z` at the top of its menu install it at once. If the update is still waiting after 7 days, a window with the release notes reminds you, then again every 7 days. `Check for Updates…` is in the menu, below `About Downtab`.

### Changed

- EmergencyRestore is now `RestoreCommandTab`, inside Downtab.app, so it updates with it: the DMG holds only Downtab.app. After a crash or a forced quit, if native ⌘Tab stays off, open Downtab and quit it from the menu bar; if Downtab doesn't start, run `/Applications/Downtab.app/Contents/MacOS/RestoreCommandTab` in Terminal.

### Removed

- The `Update Available: X.Y.Z…` menu item that opened the website: updates now install from the menu.

## [0.5.0] - 2026-11-18

### Changed

- Downtab ships as `Downtab.dmg`, signed with Developer ID and notarized by Apple: Downtab.app and EmergencyRestore open without clearing the quarantine. Open the DMG and drag Downtab.app to Applications.
- Grant Accessibility to Downtab once more after updating: the new signature no longer matches the previous grant. If Downtab doesn't react with Accessibility on, remove the old entry with `tccutil reset Accessibility io.doubleloop.downtab` and grant it again.

## [0.4.2] - 2026-11-12

### Fixed

- Switcher: holding Tab, or the Window shortcut key, with the Modifier keeps moving the selection like the native switcher, stopping on the last app or window; with ⇧, on the first. Separate presses still wrap around.
- Only one Downtab runs at a time: opening another copy while one is running shows `Downtab is already running` with the running version and location, and the new copy quits. Quit the running Downtab first to switch copies.

## [0.4.1] - 2026-11-11

### Fixed

- Switcher and Window list: on macOS 26 and later a grey rectangle no longer shows past their rounded corners on a light background.

## [0.4.0] - 2026-11-10

### Added

- Switcher: the mouse and the trackpad select like the native switcher. Moving the pointer onto an app or a window selects it; clicking an app with a Window count badge opens its Window list, clicking any other app or a window confirms it, and clicking outside the Switcher cancels without reaching the app underneath. Scrolling over the Switcher walks the Window list one window per wheel notch or per swipe, following the natural scrolling setting.

## [0.3.0] - 2026-11-09

### Added

- Preferences: `Show Switcher on` picks the display the Switcher opens on: the one under the pointer (as before), the one with the menu bar, or the one with the focused window.
- Switcher: each app shows the Notification badge of its Dock icon (unread count, dot or text) on the icon's top-right corner, like the native ⌘Tab.
- The menu bar menu shows `Update Available: X.Y.Z…` when a newer release is out; it opens the download page. Downtab checks shortly after launch, then once a day.

### Changed

- Switcher and Window list: on macOS 26 and later they use the system Liquid Glass and follow the system appearance and glass settings (Clear or Tinted, Reduce transparency, Increase contrast). macOS 15 keeps the dark look.
- Window list: a plain rounded rectangle under the selected icon, without the caret pointing at it.
- Switcher: lower, with spacing and tile size in the proportions of the native ⌘Tab; icons fill more of their tile.
- Switcher: the Window count badge sits on the icon's bottom-right corner, free to stick out of the selected tile, which now hugs the icon. It takes the size and look of the native notification badge, in blue with a white count; at Window level it turns white with a blue count.

### Fixed

- Switcher: no more square outline around its rounded corners, visible with the light system appearance.
- Window count badge: stays a circle with small icons, with a thinner ring and a readable count.

## [0.2.0] - 2026-11-09

### Changed

- Downtab is now free software, licensed under GPL-3.0-or-later. Source, releases and the download page moved to [github.com/doubleloop-io/downtab](https://github.com/doubleloop-io/downtab) and [downtab.doubleloop.io](https://downtab.doubleloop.io/).
- New bundle identifier `io.doubleloop.downtab`. After updating from 0.1.2 or earlier: grant Accessibility to Downtab again, set your shortcuts and `Launch at login` again, and remove the old Downtab entry from System Settings › Privacy & Security › Accessibility.

## [0.1.2] - 2026-11-06

### Added

- `About Downtab` in the menu bar menu shows the installed version and build.

### Fixed

- Window shortcut: pressed again quickly, it now always switches to the other window instead of sometimes doing nothing.

## [0.1.1] - 2026-11-06

### Fixed

- Preferences: the missing Accessibility permission notice no longer overlaps the shortcut fields.

## [0.1.0] - 2026-11-05

### Added

- App switcher with ⌥Tab / ⌥⇧Tab: apps in most recently used order, like the native ⌘Tab.
- Window list: descend into an app to pick a single window; ⌥` opens it on the frontmost app.
- Windows in other Spaces and full-screen apps are brought to the front.
- Custom App and Window shortcuts, including ⌘Tab and ⌘` (the native ones are turned off while in use).
- Emergency restore: turns native ⌘Tab and ⌘` back on after a crash or a forced quit.
- Guided Accessibility permission setup.
- Launch at login, on by default.
