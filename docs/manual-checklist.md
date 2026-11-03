# Manual checklist

Checks run by hand on the real app. No Swift knowledge needed: every step is a terminal command or something to look at on screen. Run the whole list before closing an issue that touches the app.

## Setup (once per clone)

1. `make setup-signing` prints `ok, identity <hex>` (or `already done`).

## Build and tests

1. `make test` ends with `core boundary ok` and `Test run with N tests ... passed`.

## Smoke

Before starting: grant Accessibility to the terminal (System Settings › Privacy & Security › Accessibility), so it can post keystrokes. Must pass before closing an issue that touches the app.

1. The shortcuts are the defaults (Preferences › `Restore Defaults`): the smoke presses ⌥Tab and `` ⌥` `` only.
2. `make smoke` ends with `smoke ok`. It launches the app, presses ⌥, ⌥Tab, ⌥⇧Tab, `` ⌥` ``, `` ⌥⇧` `` and `Esc` by itself (the front app may change), and quits the app at the end.

## App launch

1. `make run` ends with a line `designated => identifier "local.downtab" and certificate leaf = H"..."` and `running: ...`.
2. A Downtab icon (stacked rectangles) appears in the menu bar.
3. No Downtab icon appears in the Dock, and Downtab is not listed in ⌘Tab.
4. Click the menu bar icon: the menu shows `Preferences…` and `Quit Downtab`. Click `Quit Downtab`: the icon disappears.
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

## Switcher: MRU order

Before starting: `make stop`, then open TextEdit, Safari and Notes with one window each in the current Space, clicking them so that Notes is in front, then Safari, then TextEdit, all partly visible. Press `Esc` after each check.

1. `make run`, then right away hold ⌥ and press Tab: the App row starts with Notes, Safari, TextEdit, matching the on-screen front-to-back order. Apps with no visible window follow them.
2. Click the TextEdit window. ⌥Tab: TextEdit is first.
3. Click Safari's Dock icon. ⌥Tab: Safari is first.
4. Use the native ⌘Tab to switch to Notes. ⌥Tab: Notes is first.
5. Confirm TextEdit with ⌥Tab (hold ⌥, Tab until TextEdit, release). ⌥Tab: TextEdit is first.
6. Quit Safari (⌘Q). ⌥Tab: Safari is not in the App row.
7. Launch Calculator from Spotlight. ⌥Tab: Calculator is first. Quit it.

## Switcher: Modifier release never missed

Before starting: `make run`, Accessibility granted to Downtab, then open TextEdit, Safari and Notes in this order. In a second terminal run `log stream --predicate 'subsystem == "local.downtab" AND category == "keyboard"'` and keep it open.

1. In Notes, hold ⌥, press Tab, release ⌥: Safari comes to the front. The log shows no `fallback check` line.
2. Run `pkill -USR1 -x Downtab`: the log shows `modifier release tap disabled by simulation`, and Downtab keeps running.
3. Hold ⌥, press Tab twice, release ⌥: the Switcher closes at once and the highlighted app comes to the front. The log shows `modifier release confirmed by fallback check`.
4. Hold ⌥, press Tab, then press `Esc`: the Switcher closes and nothing changes. Release ⌥: nothing more happens, and the log shows no `fallback check` line.
5. `make run` restores the tap: repeat step 1.
6. macOS disabling the tap cannot be provoked on demand. If the log ever shows `modifier release tap disabled by timeout` or `... by user input`, the next line is `modifier release tap re-enabled`.

## Switcher: look

Before starting: `make run`, then open TextEdit, Safari and Notes in this order. Open `docs/prototype-switcher.html?names=below` in a browser (the bar at the bottom shows `E · name below the row, icon-only highlight`) and hold ⌥ + Tab to open its panel. Ignore the prototype's Italian texts: they are not part of this check.

1. In Notes, hold ⌥ and press Tab: the Switcher is a dark, rounded, translucent panel with a thin light border, like the prototype's, even in Light Mode and over a bright window.
2. Each app is a large icon. The selected app's icon sits in a lighter rounded tile with a thin border and an even margin on every side; the others have none.
3. Only the selected app shows its name, on its own line below the icons, centered under the selected tile and never cut by it: a long name (e.g. `ChatGPT Classic`) extends past the tile's edges without touching its highlight.
4. Press Tab a few times: the highlight and the name move, the icons do not move. Press `Esc`.
5. With many apps open (15 or more), the Switcher still fits the screen width: icons get smaller instead of overflowing.
6. With many apps open, select the first and then the last app: a name wider than its tile stays inside the panel, pushed against its left or right edge instead of centered. Press `Esc`.
7. Open a second TextEdit window (⌘N). Hold ⌥ and press Tab: TextEdit's icon has a Window count badge like the prototype's (press `B` there to cycle badge styles until it shows `cerchio`): a white disc with a blue ring and `2`, centered near the icon's bottom-right corner, inside the tile's highlight when selected. Safari and Notes, with one window each, have no badge. Press `Esc`.
8. Open 3 Finder windows: Finder's badge shows `3` (the desktop does not count). An app exposing fake dialogs (cmux, with one window) shows no badge. Press `Esc`.

## Switcher: which apps appear

Before starting: `make run`, Accessibility granted to Downtab, two Spaces (Mission Control, `+`), TextEdit, Safari and Notes open with one window each in Space 1. Wait one second after each change before pressing ⌥Tab: a change no window event reports (a window moved to another Space) is picked up by the scan that runs every second. Press `Esc` after each check.

1. From Space 1, ⌥Tab shows TextEdit, Safari and Notes.
2. Move the Notes window to Space 2 (drag it to Space 2 in Mission Control). From Space 1, ⌥Tab: Notes is not in the App row. From Space 2, ⌥Tab: Notes is there, TextEdit and Safari are not.
3. Open a second Notes window in Space 1. From Space 1, ⌥Tab: Notes is there again, with no badge (its other window is in Space 2).
4. Close all Notes windows (⌘W) without quitting Notes: Notes is in the App row from any Space, with no badge.
5. Hide Safari (⌘H) and move to Space 2: ⌥Tab shows Safari.
6. With a window in several Spaces (right click its Dock icon › Options › All Desktops): its app appears from every Space.
7. Make TextEdit full screen (green button), then go back to Space 1 (⌃←). ⌥Tab: TextEdit is in the App row. Select it and release ⌥: macOS moves to TextEdit's full-screen Space and TextEdit is frontmost.
8. From the full-screen TextEdit, ⌥Tab: every running app with a Dock icon is in the App row, including those with windows only in Space 2.
9. Two instances of the same app (e.g. `open -n -a TextEdit`): two TextEdit entries, each admitted on its own windows.
10. With two displays, each showing a different Space: apps with windows on either display appear; an app whose only window is in a Space shown on neither display does not. A window on each display counts twice towards the badge.
11. `log show --last 1h --predicate 'subsystem == "local.downtab" AND category == "private-api"'` prints nothing on a supported macOS. A line `private symbol missing: <name>, its feature is off` means macOS removed a private API: the app keeps running, and apps living in other Spaces are no longer hidden.

## Switcher: fresh window list and frozen apps

Before starting: `make run`, Accessibility granted to Downtab, TextEdit and Safari open with one window each in Space 1, a second Space. In a second terminal run `log stream --level info --predicate 'subsystem == "local.downtab" AND (category == "observer" OR category == "scan")'` and keep it open. Press `Esc` after each ⌥Tab.

1. Right after `make run` the log shows `watching window events pid=...` once per app with a Dock icon. An app that refuses shows `window events unavailable pid=... <step> error=...` instead, repeated at most every 5 s.
2. In TextEdit press ⌘N, then at once ⌥Tab: TextEdit has the `2` badge. The log shows `window event AXWindowCreated pid=...` followed by `scan changed pid=...` with TextEdit's pid (`pgrep -x TextEdit`).
3. Close that window (⌘W), then at once ⌥Tab: the badge is gone. The log shows `window event AXUIElementDestroyed`.
4. Save the TextEdit document under a new name: the log shows `window event AXTitleChanged`.
5. Minimize the TextEdit window (⌘M): the log shows `window event AXWindowMiniaturized`. Restore it from the Dock: `window event AXWindowDeminiaturized`.
6. Fallback scan: move the TextEdit window to Space 2 in Mission Control (no window event is raised for it). Within one second the log shows `scan changed pid=...` with TextEdit's pid and no `window event` line before it; from Space 1, ⌥Tab no longer shows TextEdit.
7. Frozen app: move the TextEdit window back, then run `kill -STOP $(pgrep -x TextEdit)`. Press ⌥Tab several times: the Switcher opens at once every time, TextEdit still in the App row. Within a few seconds the log shows `scan no answer pid=...` with TextEdit's pid, once per second. Open and close a Safari window: Safari's badge still updates.
8. Run `kill -CONT $(pgrep -x TextEdit)`: the `scan no answer` lines stop.
9. Quit Safari (⌘Q): within one second the log shows `stopped watching window events pid=...` with Safari's pid.

## Switcher: Window list

Before starting: `make run`, Accessibility granted to Downtab. Open TextEdit with 3 windows titled apart (⌘N three times, type `one`, `two`, `three` and save each, or just tell them apart by content), arranged so each one is partly visible, then Safari with one window, then Notes, clicking each to bring it to the front. Keep ⌥ held during each step unless the step says to release it.

1. In Notes, hold ⌥, press Tab until TextEdit is selected, press `↓`: a Window list drops under TextEdit's icon, with a caret pointing at it, a header with TextEdit's icon and `TextEdit · 3 windows`, and the 3 titles in TextEdit's front-to-back order, the first one highlighted in blue. TextEdit's badge turns blue with a white ring and `3`; its tile highlight gets fainter. Compare with `docs/prototype-switcher.html` (press `↓` there).
2. Press `↓` twice: the highlight moves down to the last window; `↓` again keeps it there. Press `↑` until the first window, then `↑` once more: the Window list closes, TextEdit is selected at App level and its badge is back to white.
3. Select Safari (one window) or an app with no windows and press `↓`: nothing happens. Press `Esc`.
4. Hold ⌥, select TextEdit, `↓`, `↓` to the second window, release ⌥: only that window comes to the front and gets the keyboard focus (type a few letters: they land in it). TextEdit's other two windows stay behind the windows of other apps that covered them before.
5. Repeat step 4 with `Enter` instead of releasing ⌥: same result, and releasing ⌥ afterwards does nothing more.
6. In TextEdit (now frontmost), hold ⌥, press Tab then ⇧Tab to come back to TextEdit, press `↓`: the second window is highlighted, not the one you are in. Release ⌥: that window comes to the front.
7. With the Window list open, press Tab: the list closes and the next app is selected. Press `Esc`: nothing changes.
8. Minimize a TextEdit window (⌘M), wait one second, select it in the Window list and release ⌥: it comes back from the Dock and to the front.
9. `log stream --predicate 'subsystem == "local.downtab" AND category == "focus"'` shows a `raise pid=... wid=... private=true ax=0` line for each window confirmed. `private=false` means a private API is missing: the window still comes forward, but with all of the app's windows, and `log show --last 1h --predicate 'subsystem == "local.downtab" AND category == "private-api"'` shows one `private symbol missing: <name>, its feature is off` line per missing symbol; the app keeps running.

## Switcher: Window shortcut

Before starting: `make run`, Accessibility granted to Downtab. Open TextEdit with 3 windows told apart by their titles (`one`, `two`, `three`), arranged so each one is partly visible, then Safari with one window, then click TextEdit's `one` window so that TextEdit is frontmost with `one` in front. Keep ⌥ held during each step unless the step says to release it. `` ⌥` `` is ⌥ plus the key left of `1` (on a US layout; on other layouts the key in that position).

1. In TextEdit, hold ⌥ and press `` ` ``: the Switcher opens with TextEdit selected and its Window list open, the second window (`two`) highlighted. Press `Esc`: nothing changes.
2. Hold ⌥, press `` ` `` twice: `three` is highlighted. Press `` ` `` again: it wraps to `one`. Press `Esc`.
3. Hold ⌥, press `` ` ``, then ⇧`` ` ``: `one` is highlighted. Press ⇧`` ` `` again: it wraps to `three`. Press `Esc`.
4. Hold ⌥ and ⇧, press `` ` ``: the Switcher opens on TextEdit's last window (`three`). Press `Esc`.
5. Press `` ⌥` `` once and release both keys quickly: only `two` comes to the front and gets the keyboard focus (type a few letters: they land in it); TextEdit's other windows stay where they were. Pressing it again brings `one` back.
6. Hold ⌥, press `` ` ``, then `↓`: `three` is highlighted. Press `↑` three times: the Window list closes and TextEdit is selected at App level. Press Tab: Safari is selected. Press `` ` ``: nothing happens. Press `Esc`.
7. Hold ⌥, press `` ` ``, then Tab: the Window list closes and Safari is selected. Release ⌥: Safari comes to the front.
8. Click TextEdit's `one` window. Hold ⌥, press `` ` ``, then `→`: TextEdit's list closes and Safari (one window) is selected without a Window list. Press `←`: TextEdit's Window list reopens. Press `Esc`.
9. Click the Safari window (one window) and press `` ⌥` ``: no Switcher appears and nothing changes. Same with `` ⌥⇧` ``, and in an app with no windows (close all TextEdit windows with ⌘W, then press `` ⌥` `` in TextEdit).
10. `log show --last 1h --predicate 'subsystem == "local.downtab" AND category == "keyboard"'` shows `` shortcut ⌥` registered `` and `` shortcut ⌥⇧` registered `` at launch, next to the ⌥Tab ones.

## Switcher: cross-app navigation

Before starting: `make run`, Accessibility granted to Downtab. Open TextEdit with 2 windows, Safari with one window, Notes with 2 windows, then Finder last (any one window), clicking each to bring it to the front, so the App row reads Finder, Notes, Safari, TextEdit. Keep ⌥ held during each step unless the step says to release it.

1. In Finder, hold ⌥, press Tab (Notes selected), press `→`: Safari is selected, its tile highlighted as at App level. Press `→` again: TextEdit is selected. Press `←` twice: Notes, then Finder is selected; `←` once more wraps to TextEdit. No Window list opens. Press `Esc`.
2. Hold ⌥, press Tab, press `↓`: Notes' Window list opens. Press `→`: Notes' list closes and Safari (one window) is selected without a Window list, its tile highlighted as at App level.
3. Press `→` again: TextEdit's Window list opens under its icon, first window highlighted. Press `→` again: it wraps to Finder (one window), selected without a list. Press `←`: TextEdit's Window list reopens.
4. With TextEdit's Window list open, press `←` twice: Safari (no list), then Notes' Window list opens on its first window. Release ⌥: only that Notes window comes to the front.
5. Hold ⌥, press Tab, `↓`, `→` (Safari, no list), release ⌥: Safari comes to the front.
6. Hold ⌥, press Tab, `↓`, `→` (Safari, no list), press Tab: the Switcher is at App level on TextEdit, no Window list. Press `↓`: TextEdit's Window list opens. Press Tab: the list closes and Finder is selected at App level. Press `Esc`: nothing changes.
7. Hold ⌥, press Tab, `↓`, `→` (Safari, no list), press `↑`: Safari is selected at App level. Press `↓`: nothing happens. Press `Esc`.

## Switcher: which windows are listed

Before starting: `make run`, Accessibility granted to Downtab, two Spaces (Mission Control, `+`), Notes open so another app is frontmost. Wait one second after each change before pressing ⌥Tab. Keep ⌥ held during each check and press `Esc` after it.

1. Finder with tabs: open 2 Finder windows (⌘N), and in one of them 3 tabs (⌘T). ⌥Tab to Finder: the badge shows `2`. Press `↓`: the Window list holds 2 entries, one per window (the one with tabs is titled after its current tab); the desktop is not listed.
2. cmux with fake dialogs: with cmux open on one window, ⌥Tab to cmux: no badge. Press `↓`: nothing happens (no `Item-0` or `Item-1` entry anywhere).
3. TextEdit minimized in another Space: open 2 TextEdit windows in Space 1 and a third one in Space 2, minimize the third one (⌘M) while in Space 2, then go back to Space 1. ⌥Tab to TextEdit: the badge shows `2`; `↓` lists only the 2 windows of Space 1.
4. Untitled: in iTerm2 (or any app with a window without a title) open 2 windows, one of them untitled (iTerm2: Settings › Profiles › Window title set to empty, or `printf '\e]0;\a'` in it). ⌥Tab to it, `↓`: the window without a title reads `Untitled`.
5. Duplicate titles: open 2 Safari windows on the same page (e.g. 2 empty Start Pages). ⌥Tab to Safari, `↓`: both entries show the same title, unchanged (no numbering).

## Switcher: accessibility

Before starting: `make run`. Step 2 needs Accessibility Inspector, which ships with Xcode (`open -a "Accessibility Inspector"`); without Xcode run step 1 only.

1. Run the command below, then within 3 seconds hold ⌥ and press Tab, and keep ⌥ held until it prints:
   `sleep 3; osascript -e 'tell application "System Events" to tell process "Downtab" to get {role, description} of UI elements of UI element 1 of window 1'`
   It prints `AXImage` once per app and the app names, in the App row order. Press `Esc`.
2. With Accessibility Inspector, point at the Switcher: the window is titled `Switcher`, it contains a list `App row`, and each entry is an `app` image labelled with the app name; only the selected entry has `Selected` set to true. Press `Esc`.
3. With Accessibility Inspector, open an app's Window list (`↓`) and point at it: a list `Window list` whose entries are `window` texts labelled with the window titles; only the selected one has `Selected` set to true. Press `Esc`.

## Preferences: shortcuts

Before starting: `make run`, Accessibility granted to Downtab, a few apps open. Open the Preferences from the menu bar icon (`Preferences…`): a `Downtab Preferences` window shows `App shortcut: ⌥Tab` and `` Window shortcut: ⌥` `` (on a non-US layout the Window shortcut shows the character of the key left of `1`, e.g. `\` on Italian), a hint line and a `Restore Defaults` button. In the commands below, `defaults read local.downtab` prints the stored shortcuts.

1. Click the App shortcut field: it gets an accent border and reads `Type shortcut`. Hold ⌃ and ⌥: it reads `⌃⌥`. Press `Esc` with nothing held: it reads `⌥Tab` again, no message.
2. Click the App shortcut field and press ⌥Tab: no Switcher opens (shortcuts are off while recording), the field reads `⌥Tab` again.
3. Click the App shortcut field and press Tab alone: a red message `Tab: Add a modifier: ⌘, ⌥ or ⌃.` appears under it, the field keeps `⌥Tab`.
4. Click it and press ⌥⇧Tab: `⌥⇧Tab: ⇧ is reserved for going back: record the shortcut without it.`
5. Click it and press `` ⌥` ``: `` ⌥`: The other shortcut already uses this combination. ``
6. Click it and press ⌘Space: `⌘Space: macOS already uses this combination: choose another one.` Same for ⌘Tab, ⌃→ and ⌘Q (Downtab does not quit).
7. Click it and press ⌃Tab: the message disappears and the field reads `⌃Tab`. Without restarting, switch apps with ⌃Tab (quick press: the previous app comes forward; until the Modifier follows custom shortcuts, a ⌃ shortcut confirms right away instead of keeping the Switcher open). ⌥Tab no longer opens the Switcher.
8. Click the Window shortcut field and press ⌃`` ` ``: it reads ``⌃` `` (or the layout's character). In an app with 2 windows, ⌃`` ` `` brings its other window forward; ⌃⇧`` ` `` its last one.
9. `make stop`, then `make run` again and open the Preferences: they still show `⌃Tab` and ``⌃` ``, and ⌃Tab still switches apps.
10. Click the App shortcut field, then click the Window shortcut field: the first one stops recording. Click the App shortcut field, then click another app's window: the field stops recording, and ⌃Tab works again.
11. Click `Restore Defaults`: the fields read `⌥Tab` and `` ⌥` `` and both work again right away. Restart (`make run`): still the defaults.
12. A shortcut another app holds is reported as used by the system: in another app that registers a global hotkey (e.g. Raycast or Alfred, `⌥Space`), record that hotkey: `macOS already uses this combination: choose another one.` and the field keeps its shortcut; `log show --last 5m --predicate 'subsystem == "local.downtab" AND category == "keyboard"'` shows `shortcut ⌥Space failed: -9878`. Skip if no such app is installed.
13. With VoiceOver on (⌘F5), move to a recorder field: it reads `App shortcut, ⌥Tab, button`; a rejection is announced. Turn VoiceOver off.

