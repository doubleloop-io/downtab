# Changelog

User-facing changes to Downtab. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow `VERSION`.

## [Unreleased]

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

- Downtab is now free software, licensed under GPL-3.0-or-later. Source, releases and the download page moved to [github.com/doubleloop-io/downtab](https://github.com/doubleloop-io/downtab) and [doubleloop-io.github.io/downtab](https://doubleloop-io.github.io/downtab/).
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
