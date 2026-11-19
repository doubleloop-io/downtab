#!/usr/bin/env bash
# Refuses a release this Mac cannot notarize, sign for Sparkle or publish: run before anything changes, so a missing
# identity, expired notary credentials, a missing Sparkle key or a gh without push access never leave a bumped, pushed
# version behind.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"

security find-identity -v -p codesigning | grep -qF "\"$DEVELOPER_ID\"" \
  || fail "signing identity missing from the keychain: $DEVELOPER_ID"
notary_output=$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>&1) \
  || fail "notary credentials unusable (keychain profile $NOTARY_PROFILE): $notary_output"
[ -x "$SPARKLE_BIN/sign_update" ] && [ -x "$SPARKLE_BIN/generate_keys" ] \
  || fail "Sparkle tools missing from $SPARKLE_BIN: run swift package resolve"
# Uses the key with both tools now: macOS may ask to allow each one, and a dialog after notarization would leave
# the release waiting halfway. Answer Always Allow.
sparkle_key=$("$SPARKLE_BIN/generate_keys" -p --account "$SPARKLE_ACCOUNT" 2>&1) \
  || fail "Sparkle private key missing from the keychain (account $SPARKLE_ACCOUNT): $sparkle_key"
[ "$sparkle_key" = "$(plist_value "$APP_INFO_PLIST" SUPublicEDKey)" ] \
  || fail "the keychain's Sparkle key ($sparkle_key) is not SUPublicEDKey in $APP_INFO_PLIST"
probe=$(mktemp)
trap 'rm -f "$probe"' EXIT
signing=$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" -p "$probe" 2>&1) \
  || fail "sign_update cannot sign with the Sparkle key (account $SPARKLE_ACCOUNT): $signing"
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated: run gh auth login"
[ "$(gh api "repos/$RELEASE_REPO" --jq .permissions.push 2>/dev/null)" = true ] \
  || fail "gh cannot publish: no push permission on $RELEASE_REPO"
[ "$(gh api "repos/$TAP_REPO" --jq .permissions.push 2>/dev/null)" = true ] \
  || fail "gh cannot update the Homebrew cask: no push permission on $TAP_REPO"
echo "release preflight ok"
