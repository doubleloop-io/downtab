#!/usr/bin/env bash
# make version V=X.Y.Z: closes the [Unreleased] changelog section as X.Y.Z and writes X.Y.Z to VERSION. Commits nothing.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
USAGE="usage: make version V=X.Y.Z (three integers, greater than the current version)"
next=${1:-}

[ -n "$next" ] || fail "$USAGE"
is_semver "$next" || fail "V=$next is not X.Y.Z. $USAGE"
current=$(read_version)
version_gt "$next" "$current" || fail "V=$next is not greater than the current version $current"
[ -f "$CHANGELOG_FILE" ] || fail "$CHANGELOG_FILE missing"
grep -qxF "## [Unreleased]" "$CHANGELOG_FILE" || fail "$CHANGELOG_FILE has no ## [Unreleased] section"
[ -n "$(changelog_entries Unreleased)" ] || fail "## [Unreleased] in $CHANGELOG_FILE has no entries: add the user-facing changes first"

today=$(date +%F)
tmp=$(mktemp)
awk -v released="## [$next] - $today" '
  $0 == "## [Unreleased]" && !done { print; print ""; print released; done = 1; next }
  { print }
' "$CHANGELOG_FILE" >"$tmp"
mv "$tmp" "$CHANGELOG_FILE"
echo "$next" >"$VERSION_FILE"

echo "version $current -> $next. Changed: $VERSION_FILE $CHANGELOG_FILE"
echo "commit them on main, then make smoke and make release"
