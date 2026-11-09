#!/usr/bin/env bash
# make ship V=X.Y.Z: checks everything that can fail before changing anything, then bumps, commits and pushes
# VERSION and CHANGELOG.md on main, then runs make release.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
USAGE="usage: make ship V=X.Y.Z (three integers, greater than the current version)"
next=${1:-}

[ -n "$next" ] || fail "$USAGE"
is_semver "$next" || fail "V=$next is not X.Y.Z. $USAGE"
current=$(read_version)
version_gt "$next" "$current" || fail "V=$next is not greater than the current version $current"
highest=$(highest_tag_version)
if [ -n "$highest" ] && ! version_gt "$next" "$highest"; then
  fail "V=$next is not greater than the latest tag v$highest"
fi

[ "$(git symbolic-ref --quiet --short HEAD || true)" = main ] || fail "ship only from main"
[ -z "$(git status --porcelain)" ] || fail "working tree not clean: commit or discard the changes first"
git fetch --quiet origin main || fail "cannot fetch origin main"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
  || fail "main differs from origin/main: pull or push first"

make test || fail "make test failed"
# Before the bump: it only changes the version string, so the smoked code is the released code.
make smoke || fail "make smoke failed"

"$(dirname "$0")/bump-version.sh" "$next" >/dev/null
echo "version $current -> $next"
git add "$VERSION_FILE" "$CHANGELOG_FILE"
git commit --quiet -m "Release v$next"
git push --quiet origin main || fail "push failed: the Release v$next commit is only local; push it, then make release"
make release
