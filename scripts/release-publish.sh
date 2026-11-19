#!/usr/bin/env bash
# Tags the release here and publishes it, with its changelog section as notes and the DMG and the Appcast as assets, in
# RELEASE_REPO, then points the Homebrew cask at the DMG. Run only after release-check.sh, notarize.sh and appcast.sh:
# a failed notarization never leaves a tag without a release. Both assets go up in one gh call: a latest release
# without its Appcast breaks updates for everyone.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
dmg=$1 appcast=$2

version=$(read_version)
tag=v$version
[ -f "$dmg" ] || fail "$dmg missing: run make notarize-check"
[ -f "$appcast" ] || fail "$appcast missing: run make notarize-check"
[ "$(appcast_value "$appcast" '//*[local-name()="shortVersionString"]')" = "$version" ] \
  || fail "$appcast does not offer $version: run make notarize-check"
notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
changelog_section "$version" >"$notes"
[ -s "$notes" ] || fail "$CHANGELOG_FILE has no ## [$version] section"

git tag -a "$tag" -m "Downtab $version"
git push origin "$tag"
gh release create "$tag" "$dmg" "$appcast" --repo "$RELEASE_REPO" --title "Downtab $version" --notes-file "$notes" \
  || fail "tag $tag pushed but the release failed; fix the cause, then rerun:
  gh release create $tag $dmg $appcast --repo $RELEASE_REPO --title \"Downtab $version\" --notes-file <(source scripts/lib/version.sh && changelog_section $version)"
echo "released $tag: https://github.com/$RELEASE_REPO/releases/tag/$tag"
# The website shows the latest release's version. The release is out either way, so a failed dispatch only warns.
gh workflow run pages.yml --repo "$RELEASE_REPO" --ref main \
  || echo "warning: the website still shows the previous version; run: gh workflow run pages.yml --repo $RELEASE_REPO --ref main"
# The release stays valid without the cask update: brew installs the previous version, which Sparkle then updates.
"$(dirname "$0")/bump-cask.sh" "$version" "$dmg" \
  || fail "released $tag but the Homebrew cask still offers the previous version; fix the cause, then run:
  scripts/bump-cask.sh $version $dmg"
