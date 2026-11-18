#!/usr/bin/env bash
# Refuses a release this Mac cannot notarize or publish: run before anything changes, so a missing identity,
# expired notary credentials or a gh without push access never leave a bumped, pushed version behind.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"

security find-identity -v -p codesigning | grep -qF "\"$DEVELOPER_ID\"" \
  || fail "signing identity missing from the keychain: $DEVELOPER_ID"
notary_output=$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>&1) \
  || fail "notary credentials unusable (keychain profile $NOTARY_PROFILE): $notary_output"
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated: run gh auth login"
[ "$(gh api "repos/$RELEASE_REPO" --jq .permissions.push 2>/dev/null)" = true ] \
  || fail "gh cannot publish: no push permission on $RELEASE_REPO"
echo "release preflight ok"
