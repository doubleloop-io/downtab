# One running Downtab, one login item

Only one Downtab runs at a time, whatever its version or location: a copy opened while another runs shows `Downtab is already running` with the running copy's version and path, then quits before touching the event taps, native ⌘Tab or the login item. Switching copies means quitting the running one first. Development launches (`make run`, `make smoke`) pass `-registerLoginItem NO`, so they never move the login item away from the installed app.

## Context

After a restart the menu bar showed two Downtabs, 0.1.2 and 0.4.1. Two causes:

- The login item (`SMAppService.mainApp`) points at the bundle that last talked to Background Task Management, and any call does it, even reading `status`: `backgroundtaskmanagementd` logs `_bundleURLForAuditToken: updating item … URL to: <calling bundle>`. Every `make run` from a checkout or worktree made that build the login item, and a copy opened from Downloads would do the same. A login item registered under an older bundle identifier (`local.downtab`, from an old clone) was never removed, so it launched alongside.
- Nothing stopped a second copy from running: two instances fight over the event taps and native ⌘Tab, and the one quitting turns native ⌘Tab back on under the other.

## Considered options

- **Register the login item only from `/Applications`.** Rejected: users may install elsewhere, and the checklist must exercise registration from a build.
- **A separate bundle identifier for development builds.** Rejected: one more Accessibility grant and separate preferences, while the signing setup aims at one grant shared by every build.
- **The newest copy replaces the running one.** Rejected: silently quitting a running copy, possibly the installed one, makes it unclear which version is running; refusing makes the switch explicit.
- **Quit the second copy without a message.** Rejected: opening an app that does nothing looks like a crash.

## Consequences

- `SingleInstance.exitIfAnotherIsRunning()` runs in `main.swift` before `AppDelegate` exists; nothing that touches `SMAppService`, the event taps or the native shortcuts may move before it.
- When two copies start together (at login and by hand), the later one quits, so they never both exit.
- `-registerLoginItem NO` arrives from the argument domain as the string `NO`: read it with `bool(forKey:)`, not `as? Bool`.
- Builds released before 0.4.2 lack the check: opened after a newer Downtab they still start alongside it.
- After launching any other copy without the flag, reopening the installed app once points the login item back at it.
- A hung but still running Downtab blocks new launches until it is killed (`make stop`).
