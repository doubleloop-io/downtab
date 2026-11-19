#!/usr/bin/env bash
# Points the cask in TAP_REPO at a released DMG: rewrites its version and sha256 and commits them through the GitHub
# contents API, so the release Mac needs no clone of the tap. Run by release-publish.sh once the release is out, or by
# hand to finish a release whose cask update failed.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
[ $# = 2 ] || fail "usage: $0 <version> <dmg>"
version=$1 dmg=$2
is_semver "$version" || fail "$version is not X.Y.Z"
[ -f "$dmg" ] || fail "$dmg missing"

sha256=$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)
contents=repos/$TAP_REPO/contents/$CASK_PATH
blob=$(gh api "$contents" --jq .sha)
current=$(gh api -H "Accept: application/vnd.github.raw+json" "$contents")
updated=$(sed -E -e "s/^(  version \")[^\"]*\"$/\1$version\"/" -e "s/^(  sha256 \")[^\"]*\"$/\1$sha256\"/" <<<"$current")
grep -qx "  version \"$version\"" <<<"$updated" && grep -qx "  sha256 \"$sha256\"" <<<"$updated" \
  || fail "$CASK_PATH in $TAP_REPO has no version or sha256 line to update"

if [ "$updated" = "$current" ]; then
  echo "cask already at $version"
  exit 0
fi
# One line: GNU base64 wraps its output.
encoded=$(base64 <<<"$updated" | tr -d '\n')
gh api --method PUT "$contents" -f message="Update downtab to $version" -f content="$encoded" -f sha="$blob" >/dev/null
echo "cask updated: brew install --cask doubleloop-io/tap/downtab installs $version"
