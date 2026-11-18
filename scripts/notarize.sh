#!/usr/bin/env bash
# Packs the Developer ID signed app (Emergency restore inside), the license and an /Applications link into a DMG,
# signs, notarizes and staples it, then verifies it as Gatekeeper judges a download. A DMG, not a zip, for the
# drag-to-Applications window.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
app=$1 dmg=$2
STAPLE_ATTEMPTS=5

stage=$(mktemp -d)
mounted=
cleanup() {
  [ -z "$mounted" ] || hdiutil detach -quiet "$mounted" || true
  rm -rf "$stage"
}
trap cleanup EXIT

mkdir "$stage/Downtab"
ditto "$app" "$stage/Downtab/$(basename "$app")"
# The GPL requires the license text to travel with the binary.
cp LICENSE "$stage/Downtab/LICENSE"
ln -s /Applications "$stage/Downtab/Applications"
rm -f "$dmg"
hdiutil create -quiet -volname Downtab -srcfolder "$stage/Downtab" -format UDZO "$dmg"
codesign --force --timestamp -s "$DEVELOPER_ID" "$dmg"

echo "notarizing $dmg: this usually takes a few minutes"
submission=$(xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json 2>&1) \
  || fail "notarization failed: $submission"
status=$(plutil -extract status raw - <<<"$submission" 2>/dev/null || true)
if [ "$status" != Accepted ]; then
  id=$(plutil -extract id raw - <<<"$submission" 2>/dev/null || true)
  log=$( [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" 2>&1 || true)
  fail "notarization status ${status:-unknown}: $submission
$log"
fi

# The ticket can take a moment to become available after the submission is accepted.
for attempt in $(seq "$STAPLE_ATTEMPTS"); do
  xcrun stapler staple -q "$dmg" && break
  [ "$attempt" -lt "$STAPLE_ATTEMPTS" ] || fail "stapling $dmg failed $STAPLE_ATTEMPTS times"
  sleep 15
done

xcrun stapler validate -q "$dmg" || fail "no valid ticket stapled to $dmg"
expect_notarized() {
  local output
  output=$(spctl -a -vvv "$@" 2>&1) || fail "Gatekeeper rejects ${*: -1}: $output"
  [[ $output == *"source=Notarized Developer ID"* ]] || fail "${*: -1} is not Notarized Developer ID: $output"
}
expect_notarized -t open --context context:primary-signature "$dmg"

mkdir "$stage/mount"
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$stage/mount" "$dmg"
mounted="$stage/mount"
listing=$(ls "$mounted" | tr '\n' ' ')
[ "$listing" = "Applications Downtab.app LICENSE " ] || fail "unexpected DMG layout: $listing"
[ "$(readlink "$mounted/Applications")" = /Applications ] || fail "the DMG Applications link does not point to /Applications"
codesign --verify --strict "$mounted/Downtab.app" || fail "Downtab.app signature broken in the DMG"
codesign --verify --strict "$mounted/Downtab.app/Contents/MacOS/restore-native-shortcuts" \
  || fail "restore-native-shortcuts signature broken in the DMG"
expect_notarized -t exec "$mounted/Downtab.app"
echo "notarized $dmg"
