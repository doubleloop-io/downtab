# Move to doubleloop-io and go public

Plan to transfer `iacoware/downtab` to the `doubleloop-io` organization, make it public, and serve the download page and releases from it instead of `iacoware/downtab-app`.

State as of 2026-11-09:

- `iacoware/downtab`: private. Issues #40–#43 were transferred here from `downtab-app`.
- `iacoware/downtab-app`: public, no open issues. It serves Pages from `main` at `/` (`https://iacoware.github.io/downtab-app/`) and holds the releases v0.1.0, v0.1.1 and v0.1.2 (latest).
- Target org: **`doubleloop-io`**, where you are admin. `doubleloop` on GitHub is a different, unrelated *user* account: never use it as the target.
- `doubleloop-io/doubleloop-io.github.io` exists and has no custom domain, so the new Pages URL will be `https://doubleloop-io.github.io/downtab/`.

## Target

| What | Before | After |
|---|---|---|
| Source and issues | `iacoware/downtab` (private) | `doubleloop-io/downtab` (public) |
| Download page | `iacoware.github.io/downtab-app` | `doubleloop-io.github.io/downtab` |
| Releases | `iacoware/downtab-app` | `doubleloop-io/downtab` |
| Page source | copied by `make publish-site` | deployed from `website/` by a GitHub Actions workflow |
| `iacoware/downtab-app` | live | redirect page only, then archived |

## 1. Before going public

### 1.1 License (#37), done

- `GPL-3.0-or-later`, copyright doubleloop. `LICENSE` holds the full text; the README has a License section.
- Why GPL: the history contains `spike/` (added in `bc425fa`, removed in `20358b2`), which takes private API signatures, offsets and parameters from AltTab's GPL-3.0 source without copying its code. GPL removes any compatibility doubt, so the history stays as is. AltTab is credited in the README.
- A paid tier stays possible under GPL: AltTab sells Pro licenses for its signed, notarized builds while its source, license check included, is public. What is sold is the convenient binary, updates and support. The name and icon are not covered by the GPL: the README requires forks to rename.
- Follow-ups:
  - Commits so far are authored by Massimo Iacolare personally. A written assignment of copyright to doubleloop makes the copyright line accurate.
  - Before merging the first external PR, set up a CLA (for example CLA Assistant with an Apache ICLA- or Harmony-based text) so doubleloop can still dual-license.
  - Selling builds needs Developer ID signing and notarization (Apple Developer Program).
- This is not legal advice; have a lawyer check the assignment and the CLA text.

### 1.2 Secret scan, done

A manual scan of all 153 commits found no secrets:

- No token or key patterns (GitHub, AWS, Slack, Google, OpenAI, PEM private keys).
- Signing material (`.signing/`, `*.p12`, `*.key`, `*.cer`, provisioning profiles) was never committed, and `.gitignore` covers it.
- No blobs over 200 KB.
- Hardcoded keychain passwords (`downtab`; `spike` in the spike) only protect a local keychain holding a self-signed certificate that is not in the repo. Not a risk.

Optional automated second pass: `brew install gitleaks && gitleaks git .`

### 1.3 Author email, decided

Most commits are authored by `info@massimoiacolare.it`, which becomes public. Accepted as is; no history rewrite.

### 1.4 Branches

| Branch | Where | State | Action |
|---|---|---|---|
| `distribute-downtab-to-friends-public-download-pa`, `docs-cleanup`, `issue-24`, `show-the-installed-version-via-an-about-downtab`, `window-list-is-not-in-mru-order`, `quick-window-shortcut-presses-sometimes-do-not-s`, `sync-the-download-page-to-iacoware-downtab-app-w` | remote | merged | already deleted; only `origin/main` remains |
| `iacoware/issue-1-next-4-issue`, `iacoware/issue-24`, `iacoware/window-list-is-not-in-mru-order` | local | merged into `main`, 0 commits ahead | delete: `git branch -d iacoware/issue-1-next-4-issue iacoware/issue-24 iacoware/window-list-is-not-in-mru-order` |
| `refs/original/refs/heads/iacoware/sync-the-download-page-to-iacoware-downtab-app-w` | local | `filter-branch` leftover | delete: `git update-ref -d refs/original/refs/heads/iacoware/sync-the-download-page-to-iacoware-downtab-app-w` |

Local refs are never published. Deleting them is only housekeeping. The `refs/pull/*` refs of closed PRs become public and cannot be deleted.

### 1.5 Closed PRs and issues

Every closed PR, issue and comment becomes public. Skim them for wording you don't want public.

## 2. Transfer

1. On GitHub: Settings → Danger Zone → Transfer → `doubleloop-io`. The repo stays private.
2. Update the local remote: `git remote set-url origin https://github.com/doubleloop-io/downtab.git`
3. Check: `gh repo view --json nameWithOwner,visibility`

GitHub redirects git and web URLs from `iacoware/downtab`. Issues, PRs, stars, Actions secrets and settings move with the repo. Pages URLs are **not** redirected (not relevant here: this repo has no Pages yet).

## 3. Make public

Settings → Danger Zone → Change visibility → Public.

After that, the reporter of #40–#43 can see those issues again.

## 4. Consolidation PR

One PR on `doubleloop-io/downtab`. Every reference to update:

### Release target

- `scripts/lib/version.sh:5`: `RELEASE_REPO=iacoware/downtab-app` → `doubleloop-io/downtab`.
- `scripts/test-versioning.sh:136,165`: expected repo strings.
- `Makefile:42`: help text.

### Pages workflow (new)

- `.github/workflows/pages.yml`: triggers on push to `main` with `paths: website/**`, plus `workflow_dispatch`.
- Steps: copy `website/downtab-landing.html` as `index.html` and `website/downtab-landing-screenshot.jpg` into a staging dir, then run `actions/upload-pages-artifact` and `actions/deploy-pages` (pin by SHA, like `ci.yml`).
- Permissions: `pages: write`, `id-token: write`.
- **Recommended**: keep the file names in `website/` and rename in the workflow, so the diff stays small. Alternative: rename to `website/index.html`, then upload `website/` as is.
- Why a workflow: deploying from a branch only supports `/` or `/docs`, not `website/`.

### Remove `publish-site`

- Delete `scripts/publish-site.sh` and `scripts/test-publish-site.sh`.
- `Makefile`: lines 3–4 (`.PHONY`), 43 (help), 59 (`test` dependency), 65–66 (`test-publish-site`), 138–139 (`publish-site`).

### Links

- `website/downtab-landing.html:177,183,232`: `iacoware/downtab-app` → `doubleloop-io/downtab`.
- `README.md:15`: the page URL.
- `README.md:43–44`: the `make release` and `make publish-site` rows.
- `README.md:61–64`: rewrite the Distribution section for one public repo.
- `README.md:77`: `website/` is deployed by the Pages workflow.
- `AGENTS.md:20` (also read as `CLAUDE.md`, which is a symlink): issue tracker `doubleloop-io/downtab`.
- `docs/agents/issue-tracker.md`: check for the repo name.
- `website/downtab-landing.html:232`: drop "Made for friends" (decided).

### Order constraint

The landing's download link (`.../releases/latest/download/Downtab.zip`) returns 404 until the new repo has a release. Merge this PR only together with step 6, or the live page breaks.

## 5. Enable Pages

Settings → Pages → Source: **GitHub Actions**. Do this before merging the PR, so its first deploy works.

## 6. First release in the new repo

The tags `v0.1.0`–`v0.1.2` already exist in this repo (only the GitHub *releases* live in `downtab-app`).

- **Recommended**: recreate the v0.1.2 release on the existing tag with the same asset, so no version bump is needed:
  ```
  gh release download v0.1.2 -R iacoware/downtab-app -p Downtab.zip -D <tmp>
  gh release create v0.1.2 <tmp>/Downtab.zip -R doubleloop-io/downtab --title "Downtab 0.1.2" \
    --notes-file <(source scripts/lib/version.sh && changelog_section 0.1.2) --verify-tag
  ```
- Alternative: bump `VERSION` and run `make release`.
- Leave v0.1.0 and v0.1.1 in `downtab-app` as history.
- Check that `https://github.com/doubleloop-io/downtab/releases/latest/download/Downtab.zip` downloads, and that `https://doubleloop-io.github.io/downtab/` loads with the screenshot.

## 7. Retire `iacoware/downtab-app`

Decided: no redirect page.

1. Point its README, description and homepage to `doubleloop-io/downtab`.
2. Archive the repo. The old page and the old releases stay online, read-only.

Known gaps: the old page `iacoware.github.io/downtab-app` stays live and still links to the old releases; an old direct link `iacoware/downtab-app/releases/latest/download/Downtab.zip` keeps serving v0.1.2 forever. This is acceptable because the app has no auto-update that reads that URL.

## 8. Afterwards

- Triage #40–#43 (no labels yet) with the canonical labels in `docs/agents/triage-labels.md`.
- Run `make test`, and `make smoke` locally, before closing issues (as `AGENTS.md` requires).

## Checklist

- [x] License chosen and `LICENSE` added (#37)
- [x] Email decision taken
- [x] Local branches and `refs/original` deleted
- [ ] Closed PRs and issues skimmed
- [x] Transferred to `doubleloop-io`, local remote updated
- [x] Repo public
- [x] Pages source set to GitHub Actions
- [x] Consolidation PR merged (#44)
- [x] v0.1.2 release in `doubleloop-io/downtab`, download and page checked
- [x] Bundle identifier renamed to `io.doubleloop.downtab` (#45)
- [x] `downtab-app` pointed to the new repo and archived
- [ ] #40–#43 triaged
