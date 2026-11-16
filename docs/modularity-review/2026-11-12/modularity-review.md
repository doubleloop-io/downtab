# Modularity Review

**Scope**: Entire codebase (`Sources/SwitcherCore`, `Sources/BackgroundAdapters`, `Sources/Downtab`, `Sources/EmergencyRestore`)
**Date**: 2026-11-12

## Executive Summary

Downtab is a macOS app switcher that behaves like the native ⌘Tab at App level and lets the user descend to a single window (Window level). Its [modularity](https://coupling.dev/posts/core-concepts/modularity/) is healthy where it matters most: the Switcher rules live in a pure `SwitcherCore`, guarded by `check-core.sh`, and the adapters talk to it through an explicit [model](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) (`DesktopSnapshot` in, `FinalEffect` out). The imbalances sit in the AppKit layer around it, inside a single team and a single deployable, so [distance](https://coupling.dev/posts/dimensions-of-coupling/distance/) is low and no issue is critical. The most important finding matches the reported pain point: `SwitcherPanel` is a [low-cohesion](https://coupling.dev/posts/core-concepts/balance/) hub that every Switcher feature (placement, pointer, badges, glass) has to edit, and part of the Switcher's behavior (when the display is chosen, when the pointer counts) is encoded implicitly in AppKit window state instead of in the core.

## Coupling Overview

| Integration | [Strength](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) | [Distance](https://coupling.dev/posts/dimensions-of-coupling/distance/) | [Volatility](https://coupling.dev/posts/dimensions-of-coupling/volatility/) | [Balanced?](https://coupling.dev/posts/core-concepts/balance/) |
| ----------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `SwitcherController` -> `Switcher` (core) | [Contract](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) (`SwitcherEvent` / `FinalEffect`) | Separate module | High (core) | Yes |
| `DesktopTracker` -> `DesktopSnapshot` / `appRow()` | [Model](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) (raw facts, rules in core) | Separate module | High | Yes |
| `WindowScanner` -> `AppRow` admission (`role` / `subrole`) | [Model](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/), partly implicit (AX strings, `nil` role semantics) | Separate module | High | Partly: see Issue 4 |
| `SwitcherController` -> `SwitcherPanel` -> `SwitcherScreen` / `SettingsStore` (display chosen at opening) | [Functional](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/), implicit (`NSWindow.isVisible`, state-equality guard) | Same module, 3 files | High (recent features) | No: Issue 1 |
| `SwitcherPanel` internals (layout, placement, pointer tracking, Window list hosting) | Low (unrelated concerns) | Same file | High | No, low cohesion: Issue 1 |
| `Switcher.isVisible` -> `alphaValue` -> `PointerPanel` / `pointerFrames` / `PointerInput` | [Functional](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/), implicit (duplicated visibility rule) | Same module, 4 files | Medium-high | No: Issue 2 |
| `ShortcutSettings` / `KeyboardInput` / `Switcher` / `SwitcherKeyTap` (current shortcuts) | [Model](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/), 4 copies synced by call order | Same package, 2 modules | Medium-high | No: Issue 3 |
| `SwitcherController` -> `ModifierReleaseTap` / `ModifierReleaseFallback` | [Functional](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) (Modifier-release rule split) | Same package, 2 modules | High | No: Issue 5 |
| `EmergencyRestore` -> `NativeShortcut.symbolicHotKeyIDs` | [Contract](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) | Separate executable | Low | Yes |
| `AppDelegate` -> `UpdateCheck`, `LaunchAtLogin`, `SingleInstance`, `PermissionMonitor` | [Contract](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) | Same module | Low (generic) | Yes |

Context used for distance: one developer, one deployable app (plus `EmergencyRestore`). The `Downtab` / `BackgroundAdapters` split is driven by concurrency isolation, not by the domain, so crossing it costs little more than crossing a file, but it does hide integration points from a reader of one module.

## Issue: `SwitcherPanel` owns placement policy and pointer tracking besides rendering

**Integration**: `SwitcherController` -> `SwitcherPanel` -> `SwitcherScreen` / `SettingsStore` / window server
**Severity**: Significant

### Knowledge Leakage

The glossary defines Switcher placement as a rule of the Switcher: "Chosen at opening; the Switcher stays on it while open". The core does not model that rule. It is reconstructed from three pieces of implicit [functional coupling](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/):

- `SwitcherPanel.show` re-chooses the display unless `NSWindow.isVisible` is already true (`SwitcherPanel.swift:55`), so "opening" means "the AppKit window was not on screen".
- `SwitcherController.handle` must skip `render()` when the state is unchanged, because "re-showing an unchanged state would choose the display again" (`SwitcherController.swift:124`).
- To choose, the view reads `SettingsStore().switcherPlacement()` and queries the window server through `SwitcherScreen` and `OnScreenWindowOrder` on the main thread, from inside a render call.

The same 418-line file also installs global and local mouse-moved monitors and arbitrates between its own and the Window list's hit-testing (`followPointer`, `pointerMoved`), hosts the Window list as a child window, computes adaptive metrics and builds the accessibility tree. These concerns share a file but very little knowledge: low strength at zero distance, which the [balance rule](https://coupling.dev/posts/core-concepts/balance/) flags as low cohesion.

### Complexity Impact

A developer changing how the panel looks has to know that `show` is also the place where a settings read and a window-server query happen, and that calling it twice in a row is not idempotent. A developer changing the controller has to know that an "optimization" guard (`state != previous`) is in fact load-bearing for a user-visible rule. Those are two non-obvious facts held across three files, on top of AppKit layout details, which pushes past what a reader keeps in working memory and makes the outcome of a change [unpredictable](https://coupling.dev/posts/core-concepts/complexity/).

### Cascading Changes

History confirms the file is the meeting point of unrelated features: Switcher placement (`eb44211`), mouse and trackpad (`1f074c5`, `5e3d3e7`), Notification badge (`06a2e8e`), Liquid Glass (`4415a0e`), spacing and badges (`5903d02`, `a8634ff`, `8999e60`). It is the most changed source file (22 commits in 6 months). Likely next changes that would cascade the same way:

- A placement such as "the display of the selected app's window" or "move the Switcher when the pointer changes display" means editing the view, the controller guard and `SwitcherScreen`.
- Rendering once more per state change (e.g. an animation, or re-rendering after an icon loads) silently moves the Switcher to another display.
- Following the pointer from a different source (e.g. a tap in `BackgroundAdapters`) means reworking `SwitcherPanel` even though it is about input, not drawing.

### Recommended Improvement

Make "opening" explicit and pull the non-rendering concerns out of the panel, keeping the rendering itself where it is:

1. Choose the display once, in `SwitcherController`, on the closed -> open transition, and pass it in: `panel.show(displayed, on: screen, icon:)`. `SwitcherScreen.forOpening` stays as is; the panel no longer reads settings or the window server, and `show` becomes idempotent, so the `state != previous` guard returns to being an optimization.
2. Move the mouse-moved monitors and the "Window list first, then App row" hit-test arbitration next to `PointerInput` (or into `PointerPanel`), leaving `SwitcherPanel` to answer `pointerTarget(at:)` for its own tiles.

Trade-off: the controller gains one responsibility (the display at opening) and `show` gains a parameter. It is worth it because the rule then has a single named home, and the panel changes only for visual reasons. Do not split the layout code further: `AppTile`, `RowSpacing` and `Metrics` are cohesive and their volatility is purely visual.

## Issue: Switcher visibility is decided in the core but enforced through `alphaValue`

**Integration**: `Switcher` (`DisplayedState.isVisible`) -> `SwitcherPanel.alphaValue` -> `PointerPanel.receivePointer`, `SwitcherPanel.pointerFrames` -> `PointerInput.switcherChanged`
**Severity**: Significant

### Knowledge Leakage

The core owns the show-delay rule (`isVisible` false until `showDelayElapsed`). The app then re-derives it from view state twice: `PointerPanel.receivePointer` drops pointer events while `alphaValue == 0`, and `SwitcherPanel.pointerFrames` returns no frames while transparent. `PointerInput` sets the outside-click capture from those frames. The business rule "the pointer does nothing before the Switcher appears" is therefore [duplicated](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) outside the core, and its correctness depends on `render()` running before `pointerFrames` is read and on `showDelayElapsed` producing a state change that triggers another `switcherChanged`.

### Complexity Impact

The core's tests cover keyboard and pointer behavior, but they cannot see this rule: a core test that sends `.pointer(.clicked)` before `showDelayElapsed` would confirm, while the real app ignores it. The behavior lives in the order of four calls in `SwitcherController.handle` and in an AppKit property, which is the kind of implicit integration a reader only discovers by breaking it.

### Cascading Changes

- Fading the Switcher in (animating `alphaValue`) changes which pointer events are accepted mid-fade.
- Changing `Switcher.showDelay` semantics (e.g. showing immediately for pointer-triggered openings) needs edits in core, `PointerPanel` and `SwitcherPanel`.
- Reordering the post-render calls in the controller can leave outside-click capture at the transparent-phase frames.

### Recommended Improvement

Move the rule to where the state is: have `Switcher.respond(to:)` ignore pointer events while `!displayed.isVisible`, with a core test, and compute the capture frames from the displayed state (`switcher.state` open and visible) rather than from `alphaValue`. `PointerPanel` then forwards every event and the panel's alpha becomes purely presentational. Cost: a few lines in the core and one test; it moves knowledge from implicit [functional coupling](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) in the app to the tested model.

## Issue: The current shortcuts live in four places, synced by call order

**Integration**: `ShortcutSettings` -> `KeyboardInput` -> `Switcher` / `SwitcherKeyTap`; `AppDelegate` -> `switcher.keyboard`
**Severity**: Significant

### Knowledge Leakage

The App and Window shortcuts exist as `ShortcutSettings.current`, `KeyboardInput.shortcuts` ("the last shortcuts registered, whether or not macOS accepted them"), `Switcher.shortcuts` (copied from the keyboard on every event in `SwitcherController.handle`) and `SwitcherKeyTap.shortcutKeyCodes`. They agree only because `ShortcutSettings.record` re-registers the current shortcuts after a refused trial, and because the controller copies before every `handle`. During a trial registration `KeyboardInput.shortcuts` holds the proposed, not yet accepted, shortcuts; this is harmless today only because recording suspends the hot keys. That is [model coupling](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) with no single owner. On top, `AppDelegate` and `ShortcutSettings` reach into `SwitcherController.keyboard` to start taps and register shortcuts, so the controller's input object is shared mutable infrastructure for three owners.

### Complexity Impact

To answer "which shortcuts does the Switcher react to right now?" a reader has to follow `PreferencesWindow` -> `ShortcutSettings` -> `KeyboardInput.register` -> `SwitcherController.handle` -> `Switcher`, and reason about the enabled flag, trial registrations and failures. The shortcut area has been [volatile](https://coupling.dev/posts/dimensions-of-coupling/volatility/) (issues #12, #16, #17, #18, #52; `KeyboardInput` co-changed with `SwitcherController` in 10 of its 20 commits).

### Cascading Changes

- A third shortcut slot, or per-slot enablement, touches all four copies and the copying site.
- Reading the Modifier from a stored shortcut instead of the pressed one (or vice versa) requires knowing which copy is authoritative at that moment.
- A failure that leaves `KeyboardInput.shortcuts` at a proposed value (e.g. an early return added in `record`) makes the core match shortcuts that macOS never registered.

### Recommended Improvement

Give the active shortcuts one owner, `ShortcutSettings`, and push changes instead of pulling copies: when `current` changes it calls `keyboard.register(current)` (registration + tap key codes) and a `SwitcherController.shortcutsChanged(current)` that sets `switcher.shortcuts` once. Drop the per-event copy and make `KeyboardInput.shortcuts` private. Let `SwitcherController` expose `startInputTaps()` rather than its `keyboard` and `pointer`, so `AppDelegate` no longer reaches through it. Cost: one more callback between settings and controller; in return the integration becomes an explicit [contract](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) and the number of copies to keep in sync drops from four to two (settings and the core), both written in one place.

## Issue: Window admission rules depend on raw Accessibility strings and on what `nil` means

**Integration**: `WindowScanner` (BackgroundAdapters) -> `DesktopWindow` -> `AppRow` admission (SwitcherCore)
**Severity**: Minor

### Knowledge Leakage

`DesktopWindow.role` and `subrole` are raw Accessibility strings, and the core matches `"AXWindow"`, `"AXStandardWindow"` and `"AXDialog"` in `isRealWindow`. Two extra meanings are encoded by convention: `role == nil` means "only the window server knows this window" (it lives in another Space), while `""` means Accessibility returned nothing. The core is pure by imports, but it still knows the Accessibility vocabulary and the scanner's merge rules: [model coupling](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) that is partly implicit.

### Complexity Impact

Admission is [core-domain](https://coupling.dev/posts/dimensions-of-coupling/volatility/) logic and has changed often (fake windows, service windows, other Spaces, full screen). A change in how the scanner merges sources, such as filling `role` for server-only windows or defaulting to `nil` instead of `""`, silently changes which apps appear in the App row, and no compiler or core test catches it because the core tests build `DesktopWindow` with their own strings.

### Cascading Changes

- Supporting a new window kind (e.g. `AXFloatingWindow` for some apps) means editing core string matches.
- Moving the window-server-only path to an event-driven source (issue #30) must preserve the `nil`-role convention exactly.

### Recommended Improvement

Let the adapter translate at the boundary into an explicit vocabulary the core owns, e.g. `kind: .standard | .dialog | .other | .notAWindow` and `source: .accessibility | .windowServerOnly`. The core keeps the rules (titled dialogs count, size thresholds, Spaces) and loses the strings. Cost: a mapping in `WindowScanner` and updated test builders. Because both sides are in the same package with one developer, the imbalance is tolerable today; do it when admission changes next, not as a standalone refactor.

## Issue: The Modifier-release fallback is wired in the controller, not in keyboard input

**Integration**: `SwitcherController` -> `ModifierReleaseFallback` / `ModifierReleaseTap.heldModifiers`; `KeyboardInput.shortcutPressed`
**Severity**: Minor

### Knowledge Leakage

Detecting the Modifier release is split across three places: the tap in `ModifierReleaseTap`, a synthetic `modifiersChanged` sent right after each hot-key press in `KeyboardInput.shortcutPressed` (to cover a release that arrived before Carbon delivered the press), and a polling fallback created and cancelled by `SwitcherController.updateMissedReleaseCheck`, which reads `ModifierReleaseTap.heldModifiers` directly. The controller thus holds [functional](https://coupling.dev/posts/dimensions-of-coupling/integration-strength/) knowledge about how keyboard events can be lost, which belongs to keyboard input.

### Complexity Impact

The rule "a Modifier release is never missed" (issue #15) has no single place to read or test as a whole. The controller is otherwise a thin event loop; this block is the main reason it co-changes with keyboard work.

### Cascading Changes

- Replacing the Carbon hot keys with the existing event tap would change the race the synthetic `modifiersChanged` compensates for, and the fallback's interval, in two files.
- A new input source that opens the Switcher (e.g. a click on the menu bar icon) must know to start the fallback.

### Recommended Improvement

Move the fallback into `KeyboardInput`: extend `captureSwitcherKeys(_:)` to `captureSwitcherKeys(open modifier: Set<ShortcutModifier>?)` so keyboard input starts and cancels its own release watch and emits `.modifiersChanged` like the tap. The controller keeps only "tell input the Switcher opened/closed". Cost: `KeyboardInput` grows by ~25 lines; acceptable because it gathers all Modifier-release knowledge in the component whose job is turning keys into `SwitcherEvent`s. Low priority: the logic is stable since #15 and the distance is small.

---

_This analysis was performed using the [Balanced Coupling](https://coupling.dev) model by [Vlad Khononov](https://vladikk.com)._
