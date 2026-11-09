# Liquid Glass on macOS 26+

On macOS 26 and later the Switcher and the Window list are built on the system glass (`NSGlassEffectView`) and follow the system appearance, so Downtab looks like the native ⌘Tab and honors the user's glass settings (Clear or Tinted, Reduce transparency, Increase contrast) without a preference of its own. macOS 15 keeps prototype variant A's dark HUD (0002). This departs from variant A, whose panel is dark whatever the system appearance.

## Considered options

- **Keep variant A everywhere.** Rejected: on macOS 26+ the Switcher would be the one opaque, always-dark panel among glass ones, and would ignore the system glass settings.
- **Glass, always dark.** Rejected: the native ⌘Tab follows the system appearance.
- **One window with a glass container, so the Window list morphs out of the Switcher.** `NSGlassEffectContainerView` merges only glass views in the same view hierarchy, while the Window list is a child window. Rejected for now: moving it into the Switcher's window reworks frames, shadow and positioning on both OS versions, and the macOS 15 path cannot be checked on a real machine.

## Consequences

- `PanelBackground` is the only place that branches on the OS version for the panels' backgrounds; `Palette` branches for colors, and doubles tile and border opacity with Increase contrast. The rest stays version-agnostic.
- On 26+ `Palette` uses system label colors and appearance-dependent tile and border colors; the Window count badge keeps its light disc on both appearances.
- The Window list drops the caret on both versions: one geometry, a rounded rectangle under the icon, its top edge where the caret tip was.
- The macOS 15 path is verified only by compiling.
