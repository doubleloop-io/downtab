# Downtab

A personal macOS app switcher. Product decisions: `docs/GOAL.md`. Terms: `GLOSSARY.md`.

## Requirements

- macOS with the Command Line Tools (Swift 6.4). Xcode is not needed.

## Commands

All commands go through `make` (run it with no target for the list). Prefer it over bare `swift build` / `swift test`: it works around a Swift 6.4 issue where a `swift build` breaks the next `swift test`.

| Command | What it does |
| --- | --- |
| `make setup-signing` | Once per clone: creates a self-signed certificate in a dedicated keychain under `.signing/` (git-ignored). The login keychain is not touched. |
| `make build` | Debug build. |
| `make test` | Runs `make check-core` and `make lint`, then the tests (Swift Testing). |
| `make check-core` | Fails if the Switcher core imports anything but Foundation, or loads private APIs. |
| `make lint` | Format check with swift-format (`.swift-format`), then SwiftLint (pinned in `Package.swift`, rules in `.swiftlint.yml`). Any violation fails. |
| `make format` | Rewrites sources with swift-format. |
| `make bundle` | Release build, assembles `build/Downtab.app` and signs it with the local certificate. |
| `make run` | Quits a running instance, bundles, then launches the app. |
| `make stop` | Quits the running app. |

## Layout

- `Sources/SwitcherCore`: pure Switcher logic, no AppKit, AX or private APIs. Tested in `Tests/SwitcherCoreTests`.
- `Sources/Downtab`: the app (menu bar item, AppKit adapters).
- `App/Info.plist`: bundle metadata (`LSUIElement`, no Dock icon).
- `Makefile`, `scripts/`: developer commands; `scripts/` holds the steps too long for a Makefile recipe.
- `docs/manual-checklist.md`: checks to run by hand on the real app.
- `spike/`: the throwaway spike, kept as a reference.

## Signing and permissions

The bundle is signed with the same certificate on every build, so the Accessibility permission survives rebuilds. Deleting `.signing/` (or a fresh clone) creates a new certificate: run `setup-signing` again and re-grant Accessibility.

CI (`.github/workflows/ci.yml`) only builds and tests; it never signs or bundles. It uses the runner's default Xcode, which can be older than the local toolchain (no hosted runner ships Swift 6.4 / the macOS 27 SDK yet); the `Versions` step logs what it ran with. Code must therefore also build with that older toolchain.
