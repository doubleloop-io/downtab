#!/usr/bin/env bash
# Tags the release here and publishes it, with its changelog section as notes and the zip as asset, in the public repo.
# Run only after release-check.sh and package.sh.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
zip=$1

version=$(read_version)
tag=v$version
[ -f "$zip" ] || fail "$zip missing: run make package"
notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
changelog_section "$version" >"$notes"
[ -s "$notes" ] || fail "$CHANGELOG_FILE has no ## [$version] section"

git tag -a "$tag" -m "Downtab $version"
git push origin "$tag"
gh release create "$tag" "$zip" --repo "$RELEASE_REPO" --title "Downtab $version" --notes-file "$notes" \
  || fail "tag $tag pushed but the release failed; fix the cause, then rerun:
  gh release create $tag $zip --repo $RELEASE_REPO --title \"Downtab $version\" --notes-file <(source scripts/lib/version.sh && changelog_section $version)"
echo "released $tag: https://github.com/$RELEASE_REPO/releases/tag/$tag"
