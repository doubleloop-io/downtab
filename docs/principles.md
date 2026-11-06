# Principles

The intent behind Downtab, kept so later changes do not betray it. Terms are defined in `GLOSSARY.md`; decisions with their trade-offs are in `docs/adr/`.

## Why Downtab exists

Existing switchers did not fit. AltTab has the right behavior, but its UI mixes apps and windows and cannot be changed; Witch did not fit either. Downtab keeps the familiar native gesture and adds only the window level.

## Principles

- **Native first.** The App row behaves like the native ⌘Tab switcher: same gesture, same most-recently-used order, and it never moves. Downtab adds only the Window level on top.
- **Raise just the selected window.** Choosing a window brings that window forward, not every window of its app.
- **Keyboard driven.** Every action is reachable from the keyboard, with the modifier held as in the native switcher. The mouse is never required.
- **Current Space only.** Downtab switches among the windows of the Current Space and never moves the user to another Space as a side effect.
- **Titles, not thumbnails.** Windows are shown by title only: no Screen Recording permission and no capture latency. Accessibility is the only permission Downtab asks for.
- **English UI.** Every label and message is in English.
