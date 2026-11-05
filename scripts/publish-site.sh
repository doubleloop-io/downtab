#!/usr/bin/env bash
# Copies the download page from website/ to the public repo's GitHub Pages site (main, root).
# Refuses unless on a clean main, so the published page always matches a commit on main.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
pages_url="https://${RELEASE_REPO%%/*}.github.io/${RELEASE_REPO#*/}/"

[ "$(git symbolic-ref --quiet --short HEAD || true)" = main ] || fail "publish-site only from main"
[ -z "$(git status --porcelain)" ] || fail "working tree not clean: commit or discard the changes first"

site=$(mktemp -d)
trap 'rm -rf "$site"' EXIT
gh repo clone "$RELEASE_REPO" "$site" -- --quiet --depth 1 || fail "cannot clone $RELEASE_REPO"
cp website/downtab-landing.html "$site/index.html"
cp website/downtab-landing-screenshot.jpg "$site/downtab-landing-screenshot.jpg"
git -C "$site" add index.html downtab-landing-screenshot.jpg
if git -C "$site" diff --cached --quiet; then
  echo "site up to date"
  exit 0
fi
git -C "$site" commit --quiet -m "Update download page from downtab $(git rev-parse --short HEAD)"
git -C "$site" push --quiet origin HEAD:main
echo "site published: $pages_url"
