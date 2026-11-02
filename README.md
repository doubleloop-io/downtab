# Downtab

A personal macOS app switcher. Product decisions: `docs/GOAL.md`. Terms: `GLOSSARY.md`.

## Requirements

- macOS with the Command Line Tools (Swift 6.4). Xcode is not needed.

## Commands

All commands go through `./scripts/downtab.sh` (run it with no arguments for the list). Prefer it over bare `swift build` / `swift test`: it works around a Swift 6.4 issue where a `swift build` breaks the next `swift test`.

| Command | What it does |
| --- | --- |
| `./scripts/downtab.sh setup-signing` | Once per clone: creates a self-signed certificate in a dedicated keychain under `.signing/` (git-ignored). The login keychain is not touched. |
| `./scripts/downtab.sh build` | Debug build (`swift build`). |
| `./scripts/downtab.sh test` | Checks the Switcher core stays free of AppKit, AX and private APIs, then runs the tests (`swift test`, Swift Testing). |
| `./scripts/downtab.sh check-core` | Fails if the Switcher core imports anything but Foundation, or loads private APIs. |
| `./scripts/downtab.sh bundle` | Release build, assembles `build/Downtab.app` and signs it with the local certificate. |
| `./scripts/downtab.sh run` | Bundles, then launches the app (quitting a running instance first). |
| `./scripts/downtab.sh stop` | Quits the running app. |

## Layout

- `Sources/SwitcherCore`: pure Switcher logic, no AppKit, AX or private APIs. Tested in `Tests/SwitcherCoreTests`.
- `Sources/Downtab`: the app (menu bar item, AppKit adapters).
- `App/Info.plist`: bundle metadata (`LSUIElement`, no Dock icon).
- `docs/manual-checklist.md`: checks to run by hand on the real app.
- `spike/`: the throwaway spike, kept as a reference.

## Signing and permissions

The bundle is signed with the same certificate on every build, so the Accessibility permission survives rebuilds. Deleting `.signing/` (or a fresh clone) creates a new certificate: run `setup-signing` again and re-grant Accessibility.

CI (`.github/workflows/ci.yml`) only builds and tests; it never signs or bundles. GitHub runners have no standalone Command Line Tools, so CI selects the Xcode whose toolchain matches the local one (Swift 6.4, macOS 27 SDK) and fails if the Swift version differs. Update both together.
