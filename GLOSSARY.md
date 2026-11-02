# Downtab

A personal macOS app switcher that behaves like the native one at the first level and lets the user descend to a single window of an app.

## Language

### Switcher

**Switcher**:
The overlay that lists apps and their windows while the modifier is held.
_Avoid_: panel, selector, picker, popup

**App row**:
The top level of the Switcher: one entry per running app, most recently used first.
_Avoid_: app bar, first row

**Window list**:
The column of window titles of one app, shown under its icon in the App row.
_Avoid_: dropdown, submenu, sub-list

**App level**:
The state in which the selection is on an app in the App row.

**Window level**:
The state in which the selection is on a window in a Window list.

**Window count badge**:
The marker on an app with more than one window, showing the count and that it can be descended into.
_Avoid_: counter, arrow

### Keys

**App shortcut**:
The modifier-plus-key combination that opens the Switcher at App level.
_Avoid_: hotkey, ⌘Tab

**Window shortcut**:
The modifier-plus-key combination that opens the Switcher at Window level on the Frontmost app.
_Avoid_: ⌘`, window cycle

**Modifier**:
The keys of the shortcut that opened the Switcher, held while it is open; releasing any of them confirms.

**Confirm**:
Bring the selected app or window to the front and close the Switcher.
_Avoid_: select, commit, switch

**Cancel**:
Close the Switcher without changing anything.
_Avoid_: dismiss, abort

### Context

**Frontmost app**:
The app that had keyboard focus when the Switcher opened.
_Avoid_: active app, current app

**Current Space**:
The Spaces visible right now, one per display.
_Avoid_: desktop, current desktop
