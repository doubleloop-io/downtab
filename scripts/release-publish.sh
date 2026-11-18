#!/usr/bin/env bash
# Tags the release here and publishes it, with its changelog section as notes and the DMG as asset, in RELEASE_REPO.
# Run only after release-check.sh and notarize.sh: a failed notarization never leaves a tag without a release.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
dmg=$1

version=$(read_version)
tag=v$version
[ -f "$dmg" ] || fail "$dmg missing: run make notarize-check"
notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
changelog_section "$version" >"$notes"
[ -s "$notes" ] || fail "$CHANGELOG_FILE has no ## [$version] section"

git tag -a "$tag" -m "Downtab $version"
git push origin "$tag"
gh release create "$tag" "$dmg" --repo "$RELEASE_REPO" --title "Downtab $version" --notes-file "$notes" \
  || fail "tag $tag pushed but the release failed; fix the cause, then rerun:
  gh release create $tag $dmg --repo $RELEASE_REPO --title \"Downtab $version\" --notes-file <(source scripts/lib/version.sh && changelog_section $version)"
echo "released $tag: https://github.com/$RELEASE_REPO/releases/tag/$tag"
