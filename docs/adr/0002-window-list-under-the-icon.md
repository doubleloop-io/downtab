# Window list drops under the selected icon

The Window list opens as a column of titles under the selected app's icon, with a caret pointing at it (variant A). Apps with more than one window carry a circular Window count badge on the bottom-right corner of the icon, and the selected app's name sits below the row instead of inside its tile. The App row never moves, so the native gesture stays intact.

## Considered options

Explored with two throwaway browser prototypes, kept in `assets/` (⌥ stands in for ⌘, which the browser cannot catch):

- `assets/prototype-ui-variants.html`, how to go from app to window: A dropdown under the icon, B fixed shelf always visible, C in-place replacement, D accordion in the row, E grid under the icon. Switch with keys 1-5 or `?variant=`.
- `assets/prototype-switcher.html`, variant A with real icons: Window count badge styles (pill, oval, circle; key `L`) and long-name fits (`?names=overhang|truncate|two-lines|grow|below`; key `N`).

The grid (E) was the closest alternative and is rejected for now: without thumbnails, titles scan better in a column, and `←` `→` stay free to change app.

## Consequences

- Colors and metrics in `Palette`, `SwitcherPanel` and `WindowListPanel` come from `assets/prototype-switcher.html` with `?names=below`.
