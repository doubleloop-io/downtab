# Manual checklist

Checks run by hand on the real app. No Swift knowledge needed: every step is a terminal command or something to look at on screen. Run the whole list before closing an issue that touches the app.

## Setup (once per clone)

1. `./scripts/downtab.sh setup-signing` prints `ok, identity <hex>` (or `already done`).

## Build and tests

1. `./scripts/downtab.sh test` ends with `core boundary ok` and `Test run with N tests ... passed`.

## App launch

1. `./scripts/downtab.sh run` ends with a line `designated => identifier "local.downtab" and certificate leaf = H"..."` and `running: ...`.
2. A Downtab icon (stacked rectangles) appears in the menu bar.
3. No Downtab icon appears in the Dock, and Downtab is not listed in ⌘Tab.
4. Click the menu bar icon: the menu shows `Quit Downtab`. Click it: the icon disappears.
5. Run `./scripts/downtab.sh run` again, then `./scripts/downtab.sh stop`: it prints `stopped` and the icon disappears.

## Signing survives rebuilds

1. Run `./scripts/downtab.sh bundle` twice. The `designated => ...` line is identical both times.
2. Once the app asks for Accessibility (later issues): grant it in System Settings › Privacy & Security › Accessibility, rebuild with `./scripts/downtab.sh run`, and check Downtab is still enabled there without granting again.
