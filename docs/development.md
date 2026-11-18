# Development

Before changing behavior read [`principles.md`](principles.md). Decisions: [`adr/`](adr/). Terms: [`GLOSSARY.md`](../GLOSSARY.md). Checks to run by hand on the real app: [`manual-checklist.md`](manual-checklist.md).

## Requirements

- macOS with the Command Line Tools (Swift 6.4). Xcode is not needed.

## Commands

All commands go through `make` (run it with no target for the list). Prefer it over bare `swift build` / `swift test`: it works around a Swift 6.4 issue where a `swift build` breaks the next `swift test`.

| Command | What it does |
| --- | --- |
| `make setup-signing` | Once per clone: creates a self-signed certificate in a dedicated keychain under `.signing/` (git-ignored) of the main checkout; git worktrees use that one too. The login keychain is not touched. |
| `make build` | Debug build. |
| `make test` | Runs `make check-core` and `make lint`, then the tests (Swift Testing). |
| `make check-core` | Fails if the Switcher core (`Sources/SwitcherCore`) imports anything but Foundation, or loads private APIs. |
| `make lint` | Format check with swift-format (`.swift-format`), then SwiftLint (pinned in `Package.swift`, rules in `.swiftlint.yml`). Any violation fails. |
| `make format` | Rewrites sources with swift-format. |
| `make icon` | Renders `App/Icon/*.svg` into `App/AppIcon.icns` (needs `rsvg-convert`). The `.icns` is committed; rerun only after editing an SVG. |
| `make bundle` | Release build, assembles `build/Downtab.app`, stamps the version (see [Versioning](releasing.md#versioning)), copies and signs `Sparkle.framework` into `Contents/Frameworks`, puts Restore ⌘Tab inside it as `Contents/MacOS/RestoreCommandTab` and signs both with the hardened runtime (a copy stays in `build/RestoreCommandTab` for `make restore`): with the Developer ID when the login keychain holds it, otherwise with the local certificate. `SIGN_WITH=developer-id` or `SIGN_WITH=self-signed` forces one. |
| `make run` | Quits a running instance, bundles, then launches the app. |
| `make stop` | Quits the running app. |

Release commands (`make notarize-check`, `make version`, `make release`, `make ship`): see [`releasing.md`](releasing.md).

## Signing and permissions

The bundle is signed with the same identity on every build, so the Accessibility permission survives rebuilds. macOS keeps one Accessibility grant per bundle id, tied to the signature's designated requirement: a build signed differently from the granted one does nothing until granted again, and that grant drops the other's.

- Where the login keychain holds the Developer ID (the release Mac), every build signs with it: `make run` and the installed release share one grant (requirement on the Team ID).
- Elsewhere, builds sign with the self-signed certificate of `make setup-signing`, plus the `disable-library-validation` entitlement (`App/SelfSigned.entitlements`): a certificate without a Team ID cannot load `Sparkle.framework` otherwise. Deleting `.signing/` (or a fresh clone) creates a new certificate: run `setup-signing` again and re-grant Accessibility. Running a release there too means re-granting at each switch.

`App/Info.plist` holds the bundle metadata (`LSUIElement`, no Dock icon) and Sparkle's settings (Appcast URL, public key, daily automatic checks and installs); no version keys, `make bundle` stamps them.

## CI

CI (`.github/workflows/ci.yml`) only builds and tests; it never signs or bundles. It uses the runner's default Xcode, which can be older than the local toolchain (no hosted runner ships Swift 6.4 / the macOS 27 SDK yet); the `Versions` step logs what it ran with. Code must therefore also build with that older toolchain.
