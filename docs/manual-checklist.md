# Manual checklist

Checks run by hand on the real app. No Swift knowledge needed: every step is a terminal command or something to look at on screen. Run the whole list before closing an issue that touches the app.

## Setup (once per clone)

1. `make setup-signing` prints `ok, identity <hex>` (or `already done`).

## Build and tests

1. `make test` ends with `core boundary ok` and `Test run with N tests ... passed`.

## App launch

1. `make run` ends with a line `designated => identifier "local.downtab" and certificate leaf = H"..."` and `running: ...`.
2. A Downtab icon (stacked rectangles) appears in the menu bar.
3. No Downtab icon appears in the Dock, and Downtab is not listed in ⌘Tab.
4. Click the menu bar icon: the menu shows `Quit Downtab`. Click it: the icon disappears.
5. Run `make run` again, then `make stop`: it prints `stopped` and the icon disappears.

## Signing survives rebuilds

1. Run `make bundle` twice. The `designated => ...` line is identical both times.
2. Once the app asks for Accessibility (later issues): grant it in System Settings › Privacy & Security › Accessibility, rebuild with `make run`, and check Downtab is still enabled there without granting again.

## Switcher: open and Cancel

Before starting: `make run`, then open TextEdit, Safari and Notes in this order, clicking each to bring it to the front.

1. In Notes, press ⌥Tab once and release: the Switcher appears in the middle of the screen with the icons of Notes, Safari, TextEdit (most recently used first), Safari highlighted, and `Safari` written under the icons.
2. The menu bar still shows `Notes` as the active app while the Switcher is open.
3. Press `Esc`: the Switcher disappears. Type a few letters: they appear in Notes, without clicking anywhere first.
4. With two displays: move the pointer to the other display and press ⌥Tab: the Switcher appears on the display under the pointer. Press `Esc`.
5. Make Safari full screen (green button), press ⌥Tab: the Switcher appears above the full-screen Safari. Press `Esc`: Safari is still full screen and frontmost.
6. Switch to another Space (⌃→) and press ⌥Tab: the Switcher appears there too. Press `Esc`.
7. With the Switcher open, press ⌥Tab again: the icons stay in the same order. Press `Esc`.
8. Opening shows no delay: the Switcher appears as soon as ⌥Tab is pressed, even right after launching a new app.
