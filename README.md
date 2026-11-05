# Downtab

A personal macOS app switcher. Product decisions: `docs/GOAL.md`. Terms: `GLOSSARY.md`.

## Requirements

- macOS with the Command Line Tools (Swift 6.4). Xcode is not needed.

## Commands

All commands go through `make` (run it with no target for the list). Prefer it over bare `swift build` / `swift test`: it works around a Swift 6.4 issue where a `swift build` breaks the next `swift test`.

| Command | What it does |
| --- | --- |
| `make setup-signing` | Once per clone: creates a self-signed certificate in a dedicated keychain under `.signing/` (git-ignored) of the main checkout; git worktrees use that one too. The login keychain is not touched. |
| `make build` | Debug build. |
| `make test` | Runs `make check-core` and `make lint`, then the tests (Swift Testing). |
| `make check-core` | Fails if the Switcher core imports anything but Foundation, or loads private APIs. |
| `make lint` | Format check with swift-format (`.swift-format`), then SwiftLint (pinned in `Package.swift`, rules in `.swiftlint.yml`). Any violation fails. |
| `make format` | Rewrites sources with swift-format. |
| `make icon` | Renders `App/Icon/*.svg` into `App/AppIcon.icns` (needs `rsvg-convert`). The `.icns` is committed; rerun only after editing an SVG. |
| `make bundle` | Release build, assembles `build/Downtab.app`, stamps the version (see Versioning) and signs it with the local certificate. |
| `make run` | Quits a running instance, bundles, then launches the app. |
| `make stop` | Quits the running app. |
| `make version V=X.Y.Z` | Closes `## [Unreleased]` in `CHANGELOG.md` as `## [X.Y.Z] - <today>` and writes `X.Y.Z` to `VERSION`. Refuses a malformed or non-greater `V`, or an empty `[Unreleased]`. Commits nothing. |
| `make release` | Refuses unless on `main`, clean, not shallow, `VERSION` greater than every `v*` tag, no tag or public release for it yet, a non-empty changelog section for it, and `make test` passing. Packaging and publishing: #23. |

## Versioning

- `VERSION` holds the version `X.Y.Z` (one line), written into the bundle as `CFBundleShortVersionString`.
- The build number (`CFBundleVersion`) is the commit count of `HEAD`, computed by `make bundle`; it only grows because releases are built from `main`. A shallow clone has no reliable count, so `make bundle` refuses it.
- `CHANGELOG.md` is written for users ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)): it becomes the public release notes.

Release:

1. Add user-facing entries under `## [Unreleased]` in `CHANGELOG.md` while working.
2. `make version V=X.Y.Z`, commit on `main`.
3. `make smoke` (manual, needs Accessibility).
4. `make release` (from `main`).

## Layout

- `Sources/SwitcherCore`: pure Switcher logic, no AppKit, AX or private APIs. Tested in `Tests/SwitcherCoreTests`.
- `Sources/Downtab`: the app (menu bar item, AppKit adapters).
- `App/Info.plist`: bundle metadata (`LSUIElement`, no Dock icon); no version keys, `make bundle` stamps them.
- `Makefile`, `scripts/`: developer commands; `scripts/` holds the steps too long for a Makefile recipe.
- `docs/manual-checklist.md`: checks to run by hand on the real app.
- `spike/`: the throwaway spike, kept as a reference.

## Signing and permissions

The bundle is signed with the same certificate on every build, so the Accessibility permission survives rebuilds. Deleting `.signing/` (or a fresh clone) creates a new certificate: run `setup-signing` again and re-grant Accessibility.

CI (`.github/workflows/ci.yml`) only builds and tests; it never signs or bundles. It uses the runner's default Xcode, which can be older than the local toolchain (no hosted runner ships Swift 6.4 / the macOS 27 SDK yet); the `Versions` step logs what it ran with. Code must therefore also build with that older toolchain.
