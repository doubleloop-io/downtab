# Releasing

To prepare a Mac to release, follow [`release-mac-setup.md`](release-mac-setup.md).

## Commands

| Command | What it does |
| --- | --- |
| `make notarize-check` | Release Mac only. Checks the release preflight (see [Distribution](#distribution)), bundles with the Developer ID, packs `Downtab.app` (Restore ⌘Tab inside), `LICENSE` and an `/Applications` link into `build/Downtab.dmg`, signs, notarizes and staples it, then verifies it with `stapler validate` and `spctl` (`Notarized Developer ID`), and signs it for Sparkle into `build/appcast.xml`. Tags and publishes nothing; `make release` runs the same steps. |
| `make version V=X.Y.Z` | Closes `## [Unreleased]` in `CHANGELOG.md` as `## [X.Y.Z] - <today>` and writes `X.Y.Z` to `VERSION`. Refuses a malformed or non-greater `V`, or an empty `[Unreleased]`. Commits nothing. |
| `make release` | Refuses unless on `main`, clean, not shallow, `VERSION` greater than every `v*` tag, no tag or public release for it yet, a non-empty changelog section for it, and `make test` passing. Then runs `make notarize-check`, tags `vX.Y.Z`, pushes the tag, publishes the release with `Downtab.dmg` and `appcast.xml` in this repo and points the Homebrew cask at the new DMG (see [Distribution](#distribution)). |
| `make ship V=X.Y.Z` | Refuses unless `V` is valid and greater than `VERSION` and every `v*` tag, on a clean `main` equal to `origin/main`, the release preflight passes, and `make test`, `make smoke` and `make notarize-check` pass. Then `make version`, commits `VERSION` and `CHANGELOG.md` as `Release vX.Y.Z`, pushes `main` and runs `make release`. |

## Versioning

- `VERSION` holds the version `X.Y.Z` (one line), written into the bundle as `CFBundleShortVersionString`.
- The build number (`CFBundleVersion`) is the commit count of `HEAD`, computed by `make bundle`; it only grows because releases are built from `main`. A shallow clone has no reliable count, so `make bundle` refuses it.
- `CHANGELOG.md` is written for users ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)): it becomes the public release notes.

## Release

1. Add user-facing entries under `## [Unreleased]` in `CHANGELOG.md` while working.
2. `make version V=X.Y.Z`, commit on `main`.
3. `make smoke` (manual, needs Accessibility).
4. `make release` (from `main`).

Or, after step 1, `make ship V=X.Y.Z` runs steps 2–4, smoke and `make notarize-check` first. If it fails after the push, fix the cause and rerun `make release`: notarization can still fail then, but only on a transient error (notary or timestamp outage, network).

## Distribution

Users download from this repo:

- The download page is its GitHub Pages site, deployed by `.github/workflows/pages.yml` on every push to `main` that touches `website/` and, dispatched by `make release`, after every release: it publishes `website/downtab-landing.html` as `index.html` with `DOWNTAB_VERSION` replaced by the latest release's tag, next to the demo video `downtab-demo.mp4`, its cover `downtab-demo-cover.jpg` and the social preview `downtab-og.jpg`. URL: `https://downtab.doubleloop.io/`. `website/recording/` holds the unpublished sources: the recording prop `backdrop.html` and `og-image.html`, which renders `downtab-og.jpg`.
- Its releases carry `Downtab.dmg`, published by `make release` with the version's `CHANGELOG.md` section as notes. Stable link: `https://github.com/doubleloop-io/downtab/releases/latest/download/Downtab.dmg`. Releases up to 0.4.2 carry `Downtab.zip` instead.
- Each release also carries `appcast.xml`, the Appcast Sparkle reads at `https://github.com/doubleloop-io/downtab/releases/latest/download/appcast.xml` (`SUFeedURL`): publishing the release is what ships the Update to installed copies, no website deploy. `make notarize-check` writes it to `build/appcast.xml` after stapling (`scripts/appcast.sh`; stapling changes the DMG, so an earlier signature would not match): one item with the app's `CFBundleVersion` and version, its `LSMinimumSystemVersion`, arm64 only, the changelog section as Markdown notes, and an enclosure pointing at the versioned asset `releases/download/vX.Y.Z/Downtab.dmg` with its length and EdDSA signature. It refuses unless the keychain's key is the app's `SUPublicEDKey`, the signature verifies and the XML is valid. `make release` uploads the DMG and the Appcast in the same `gh release create`.
- A latest release without `appcast.xml` breaks updates for everyone: Sparkle finds no feed. If one goes out without it, upload it: `gh release upload vX.Y.Z build/appcast.xml`, from the `build/` of that release's `make release` (or rerun `make notarize-check` on the tagged commit first).
- Apple Silicon only. Releases are signed with `Developer ID Application: doubleloop srl (49CP6UC6KC)`, notarized and stapled. Restore ⌘Tab ships inside `Downtab.app`, so it updates with the app. A DMG, not a zip, for the drag-to-Applications window. `make run` and `make smoke` sign with the Developer ID too where the login keychain holds it (see [Signing and permissions](development.md#signing-and-permissions)), and with the self-signed certificate elsewhere, so contributors need no Apple account.
- The release Mac holds the identity in the login keychain and the notarytool credentials in the keychain profile `downtab-notary`. The release preflight, run by `make ship` before anything changes and by `make notarize-check`, checks both, that the Sparkle key below is in the keychain, matches `SUPublicEDKey` and signs, and that `gh` is authenticated with push permission on this repo and on the Homebrew tap.
- The release Mac also holds the Sparkle EdDSA private key that signs updates, in the login keychain under the account `io.doubleloop.downtab` (`generate_keys -p --account io.doubleloop.downtab` prints its public key, `SUPublicEDKey`). Its backup, the file `downtab-sparkle-key`, lives in the team password manager, never in the repo. Losing the key means installed copies can never update again. To use it on another Mac: `generate_keys -f downtab-sparkle-key --account io.doubleloop.downtab`. The `generate_keys` and `sign_update` tools are in `.build/artifacts/sparkle/Sparkle/bin/` once the package is resolved (`swift package resolve`). macOS asks once per tool to let it use the key: answer `Always Allow`. The preflight uses the key with both tools, so the dialogs show before notarization, never halfway through a release.
- If `make release` fails after pushing the tag, it prints the `gh release create` command to finish by hand, with both assets. Notarization runs before the tag, so it never leaves a tag without a release.
- Homebrew: `brew install --cask doubleloop-io/tap/downtab`, from our own tap [`doubleloop-io/homebrew-tap`](https://github.com/doubleloop-io/homebrew-tap) (the official `homebrew/cask` only takes notable projects). Its `Casks/downtab.rb` points at the versioned asset `releases/download/vX.Y.Z/Downtab.dmg`. After publishing the release, `make release` runs `scripts/bump-cask.sh`, which rewrites the cask's `version` and `sha256` and commits them through the GitHub contents API, no clone needed; the release preflight checks that `gh` can push to the tap. If the bump fails the release stays valid (brew installs the previous version, which Sparkle then updates): `make release` prints `scripts/bump-cask.sh X.Y.Z build/Downtab.dmg` to finish by hand. The cask has `auto_updates true`, so `brew upgrade` leaves Downtab to Sparkle; `brew uninstall` quits it, which turns native ⌘Tab back on, and `--zap` also removes its preferences and caches. Neither removes the login item or the Accessibility grant. The tap's CI runs `brew style` and `brew audit --strict --online` on every push and pull request.
