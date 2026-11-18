# Downtab

A macOS app switcher that works like ⌘Tab, and lets you drop down to a single window of an app.

![Downtab switcher](website/downtab-demo-cover.jpg)

Entirely keyboard-driven: `⌥Tab`, `Tab`, `Tab`, `↓`, `↓`, `release`.

- **Feels like ⌘Tab**: hold ⌥ and press Tab to see apps in most-recently-used order.
- **Drop down to a window**: press ↓ on an app with two or more windows to pick just the one you want.
- **Window shortcut**: ⌥` opens the switcher on the current app with its windows already listed.
- **Current Space only**: only windows on the Spaces you're looking at, on every display.
- **Titles, no thumbnails**: no Screen Recording permission, no capture lag.

macOS 15 or later · Apple Silicon only. Download, install steps and troubleshooting: **[downtab.doubleloop.io](https://downtab.doubleloop.io/)**.

## Documentation

- [Development](docs/development.md): requirements, `make` commands, signing and permissions, CI.
- [Releasing](docs/releasing.md): versioning, release steps, distribution.
- [Release Mac setup](docs/release-mac-setup.md): how to prepare a Mac to release.
- [Principles](docs/principles.md): the intent later changes must not betray.
- [Decisions](docs/adr/) and [Glossary](GLOSSARY.md).

## License

Copyright © 2026 doubleloop.

Downtab is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version (`GPL-3.0-or-later`). See [`LICENSE`](LICENSE).

- **Name and icon**: the license covers the code, not the Downtab name or icon. Forks that distribute builds must use a different name and icon.
- **Contributions**: external contributions will require signing a Contributor License Agreement (CLA) before they can be merged.
- **Acknowledgments**: some interoperability facts about private macOS APIs (function signatures, record offsets, symbolic hotkey ids, the remote-token window lookup) were learned by reading [AltTab](https://github.com/lwouis/alt-tab-macos) (GPL-3.0). No AltTab code is copied.
