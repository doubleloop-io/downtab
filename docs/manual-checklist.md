# Manual checklist

Checks run by hand on the real app. No Swift knowledge needed: every step is a terminal command or something to look at on screen. Run the whole list before closing an issue that touches the app.

## Setup (once per clone)

1. `make setup-signing` prints `ok, identity <hex>` (or `already done`).

## Build and tests

1. `make test` ends with `core boundary ok` and `Test run with N tests ... passed`.

## Smoke

Before starting: grant Accessibility to the terminal (System Settings › Privacy & Security › Accessibility), so it can post keystrokes. Must pass before closing an issue that touches the app.

1. `make smoke` ends with `smoke ok`. It launches the app, presses ⌥, ⌥Tab, ⌥⇧Tab and `Esc` by itself (the front app may change), and quits the app at the end.

## App launch

1. `make run` ends with a line `designated => identifier "local.downtab" and certificate leaf = H"..."` and `running: ...`.
2. A Downtab icon (stacked rectangles) appears in the menu bar.
3. No Downtab icon appears in the Dock, and Downtab is not listed in ⌘Tab.
4. Click the menu bar icon: the menu shows `Quit Downtab`. Click it: the icon disappears.
5. Run `make run` again, then `make stop`: it prints `stopped` and the icon disappears.

## Signing survives rebuilds

1. Run `make bundle` twice. The `designated => ...` line is identical both times.
2. Grant Accessibility (needed from now on to detect the ⌥ release) in System Settings › Privacy & Security › Accessibility, rebuild with `make run`, and check Downtab is still enabled there without granting again.

## Switcher: open and Cancel

Before starting: `make run`, then open TextEdit, Safari and Notes in this order, clicking each to bring it to the front. In this section keep ⌥ held until `Esc`: releasing it confirms.

1. In Notes, press ⌥Tab and keep ⌥ held: the Switcher appears in the middle of the screen with the icons of Notes, Safari, TextEdit (most recently used first), Safari highlighted, and `Safari` written under the icons.
2. The menu bar still shows `Notes` as the active app while the Switcher is open.
3. Press `Esc`: the Switcher disappears. Type a few letters: they appear in Notes, without clicking anywhere first.
4. With two displays: move the pointer to the other display and press ⌥Tab: the Switcher appears on the display under the pointer. Press `Esc`.
5. Make Safari full screen (green button), press ⌥Tab: the Switcher appears above the full-screen Safari. Press `Esc`: Safari is still full screen and frontmost.
6. Switch to another Space (⌃→) and press ⌥Tab: the Switcher appears there too. Press `Esc`.
7. With the Switcher open, press ⌥Tab again: the icons stay in the same order. Press `Esc`.
8. Opening shows no delay: the Switcher appears as soon as ⌥Tab is pressed, even right after launching a new app.

## Switcher: cycle and Confirm at App level

Before starting: `make run`, Accessibility granted to Downtab, then open TextEdit, Safari and Notes in this order, clicking each to bring it to the front.

1. In Notes, press ⌥Tab once and release both keys quickly: Safari comes to the front (menu bar shows `Safari`).
2. Press ⌥Tab once and release again: Notes comes back to the front.
3. Hold ⌥, press Tab twice: TextEdit is highlighted. Release ⌥: TextEdit comes to the front with its windows.
4. Hold ⌥, press Tab until the highlight passes the last icon: it wraps to the first icon. Release ⌥: that app comes to the front.
5. Hold ⌥, press Tab, then ⇧Tab: the highlight moves back to the first icon. Press ⇧Tab again: it wraps to the last icon. Press `Esc`: nothing changes.
6. Hold ⌥ and ⇧, press Tab: the Switcher opens on the last icon. Press `Esc`.
7. Hold ⌥, press Tab, then press `Enter` without releasing ⌥: the highlighted app comes to the front and the Switcher closes. Releasing ⌥ afterwards does nothing more.
8. Hide Safari (⌘H), then hold ⌥, select Safari and release: Safari comes back to the front.
9. `log stream --predicate 'subsystem == "local.downtab"'` shows `modifier release tap started` at launch and an `activate pid=... ok=true` line for each Confirm.

## Switcher: look

Before starting: `make run`, then open TextEdit, Safari and Notes in this order. Open `docs/prototype-switcher.html?names=below` in a browser (the bar at the bottom shows `E · name below the row, icon-only highlight`) and hold ⌥ + Tab to open its panel. Ignore the prototype's Window count badges and Italian texts: they are not part of this check.

1. In Notes, hold ⌥ and press Tab: the Switcher is a dark, rounded, translucent panel with a thin light border, like the prototype's, even in Light Mode and over a bright window.
2. Each app is a large icon. The selected app's icon sits in a lighter rounded tile with a thin border and an even margin on every side; the others have none.
3. Only the selected app shows its name, on its own line below the icons, centered under the selected tile and never cut by it: a long name (e.g. `ChatGPT Classic`) extends past the tile's edges without touching its highlight.
4. Press Tab a few times: the highlight and the name move, the icons do not move. Press `Esc`.
5. With many apps open (15 or more), the Switcher still fits the screen width: icons get smaller instead of overflowing.
6. With many apps open, select the first and then the last app: a name wider than its tile stays inside the panel, pushed against its left or right edge instead of centered. Press `Esc`.

## Switcher: accessibility

Before starting: `make run`. Step 2 needs Accessibility Inspector, which ships with Xcode (`open -a "Accessibility Inspector"`); without Xcode run step 1 only.

1. Run the command below, then within 3 seconds hold ⌥ and press Tab, and keep ⌥ held until it prints:
   `sleep 3; osascript -e 'tell application "System Events" to tell process "Downtab" to get {role, description} of UI elements of UI element 1 of window 1'`
   It prints `AXImage` once per app and the app names, in the App row order. Press `Esc`.
2. With Accessibility Inspector, point at the Switcher: the window is titled `Switcher`, it contains a list `App row`, and each entry is an `app` image labelled with the app name; only the selected entry has `Selected` set to true. Press `Esc`.
