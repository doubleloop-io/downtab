#!/usr/bin/env bash
# Tests the versioning scripts against throwaway git repos; gh and make are stubbed.
set -uo pipefail
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
failures=0
TODAY=$(date +%F)

failed() { echo "FAIL: $1"; failures=$((failures + 1)); }

# Stubs: `gh release view` answers from $GH_RELEASES; `gh release create` logs its arguments to $ROOT/gh-create
# and its notes to $ROOT/gh-notes, then exits with $GH_CREATE_EXIT; `gh auth status` exits with $GH_AUTH_EXIT;
# `gh api` prints $GH_PUSH (default true) as the push permission. `make <target>` appends the target to
# $ROOT/make-calls and exits with $MAKE_TEST_EXIT, $MAKE_SMOKE_EXIT, $MAKE_NOTARIZE_EXIT or $MAKE_RELEASE_EXIT.
# `security find-identity` lists $SIGNING_IDENTITY (default the release one); `xcrun notarytool` exits with
# $NOTARY_EXIT. Sparkle's `generate_keys` prints $SPARKLE_KEY (default the test key) or exits with
# $GENERATE_KEYS_EXIT; `sign_update` prints a fake signature or exits with $SIGN_EXIT, and `--verify` exits with
# $SIGN_VERIFY_EXIT.
mkdir -p "$ROOT/bin" "$ROOT/sparkle"
cat >"$ROOT/bin/gh" <<STUB
#!/usr/bin/env bash
[ "\$1" = auth ] && exit "\${GH_AUTH_EXIT:-0}"
[ "\$1" = api ] && { echo "\${GH_PUSH:-true}"; exit 0; }
[ "\$1" = workflow ] && { echo "\$*" >"$ROOT/gh-workflow"; exit 0; }
if [ "\$2" = create ]; then
  echo "\$*" >"$ROOT/gh-create"
  while [ \$# -gt 0 ]; do [ "\$1" = --notes-file ] && cat "\$2" >"$ROOT/gh-notes"; shift; done
  exit "\${GH_CREATE_EXIT:-0}"
fi
[[ " \${GH_RELEASES:-} " == *" \$3 "* ]] && { echo "\$3"; exit 0; }
echo "release not found"; exit 1
STUB
cat >"$ROOT/bin/make" <<STUB
#!/usr/bin/env bash
echo "\$1" >>"$ROOT/make-calls"
case "\$1" in
  smoke) exit "\${MAKE_SMOKE_EXIT:-0}" ;;
  notarize-check) exit "\${MAKE_NOTARIZE_EXIT:-0}" ;;
  release) exit "\${MAKE_RELEASE_EXIT:-0}" ;;
  *) exit "\${MAKE_TEST_EXIT:-0}" ;;
esac
STUB
RELEASE_IDENTITY=$(source "$SCRIPTS/lib/version.sh" && echo "$DEVELOPER_ID")
cat >"$ROOT/bin/security" <<STUB
#!/usr/bin/env bash
echo "  1) 0123456789ABCDEF \"\${SIGNING_IDENTITY-$RELEASE_IDENTITY}\""
STUB
cat >"$ROOT/bin/xcrun" <<STUB
#!/usr/bin/env bash
[ "\${NOTARY_EXIT:-0}" = 0 ] || { echo "No Keychain password item found"; exit "\$NOTARY_EXIT"; }
STUB
TEST_KEY=test-public-key
SIGNATURE=fake-signature
cat >"$ROOT/sparkle/generate_keys" <<STUB
#!/usr/bin/env bash
[ "\${GENERATE_KEYS_EXIT:-0}" = 0 ] || { echo "no key"; exit "\$GENERATE_KEYS_EXIT"; }
echo "\${SPARKLE_KEY-$TEST_KEY}"
STUB
cat >"$ROOT/sparkle/sign_update" <<STUB
#!/usr/bin/env bash
[[ " \$* " == *" --verify "* ]] && exit "\${SIGN_VERIFY_EXIT:-0}"
[ "\${SIGN_EXIT:-0}" = 0 ] || { echo "no key"; exit "\$SIGN_EXIT"; }
echo $SIGNATURE
STUB
chmod +x "$ROOT/bin/gh" "$ROOT/bin/make" "$ROOT/bin/security" "$ROOT/bin/xcrun" "$ROOT/sparkle/generate_keys" \
  "$ROOT/sparkle/sign_update"
export PATH="$ROOT/bin:$PATH" SPARKLE_BIN="$ROOT/sparkle"

# A repo on main at VERSION 0.1.0, released as v0.1.0, with one Unreleased entry and the app's Info.plist holding the
# test key; everything committed.
new_repo() {
  local repo
  repo=$(mktemp -d "$ROOT/repo.XXXX")
  cd "$repo" || exit 1
  git init -q -b main
  echo 0.1.0 >VERSION
  mkdir App
  plutil -create xml1 App/Info.plist && plutil -insert SUPublicEDKey -string "$TEST_KEY" App/Info.plist
  printf '# Changelog\n\n## [Unreleased]\n\n### Added\n\n- New thing\n\n## [0.1.0] - 2026-01-01\n\n### Added\n\n- First thing\n' >CHANGELOG.md
  git add . && git commit -qm init && git tag v0.1.0
}

commit_all() { git add -A && git commit -qm change; }

# expect_refusal <name> <message fragment> <command...>
expect_refusal() {
  local name=$1 fragment=$2 output
  shift 2
  if output=$("$@" 2>&1); then failed "$name: succeeded, expected refusal"; return; fi
  [[ $output == *"$fragment"* ]] || failed "$name: expected '$fragment', got: $output"
}

expect_success() {
  local name=$1 output
  shift
  output=$("$@" 2>&1) || failed "$name: $output"
}

# make version refusals
new_repo
expect_refusal "version without V" "usage" "$SCRIPTS/bump-version.sh"
for malformed in 1.2 1.2.3-rc.1 a.b.c 01.2.3 1.2.3.4; do
  expect_refusal "version V=$malformed" "not X.Y.Z" "$SCRIPTS/bump-version.sh" "$malformed"
done
expect_refusal "version equal" "not greater" "$SCRIPTS/bump-version.sh" 0.1.0
expect_refusal "version lower" "not greater" "$SCRIPTS/bump-version.sh" 0.0.9
echo 0.10.0 >VERSION
expect_refusal "version compared numerically" "not greater" "$SCRIPTS/bump-version.sh" 0.9.0

new_repo
printf '0.1.0\n7\n' >VERSION
expect_refusal "version with malformed VERSION" "malformed" "$SCRIPTS/bump-version.sh" 0.2.0
rm VERSION
expect_refusal "version with missing VERSION" "missing" "$SCRIPTS/bump-version.sh" 0.2.0

new_repo
printf '# Changelog\n\n## [0.1.0] - 2026-01-01\n\n- First thing\n' >CHANGELOG.md
expect_refusal "version without Unreleased" "no ## [Unreleased]" "$SCRIPTS/bump-version.sh" 0.2.0
printf '# Changelog\n\n## [Unreleased]\n\n### Added\n\n## [0.1.0] - 2026-01-01\n\n- First thing\n' >CHANGELOG.md
expect_refusal "version with empty Unreleased" "no entries" "$SCRIPTS/bump-version.sh" 0.2.0
[ "$(cat VERSION)" = 0.1.0 ] || failed "refused version changed VERSION"

# make version on a valid tree
new_repo
expect_success "version V=0.2.0" "$SCRIPTS/bump-version.sh" 0.2.0
[ "$(cat VERSION)" = 0.2.0 ] || failed "VERSION after bump: $(cat VERSION)"
expected=$(printf '# Changelog\n\n## [Unreleased]\n\n## [0.2.0] - %s\n\n### Added\n\n- New thing\n\n## [0.1.0] - 2026-01-01\n\n### Added\n\n- First thing' "$TODAY")
[ "$(cat CHANGELOG.md)" = "$expected" ] || failed "CHANGELOG after bump: $(cat CHANGELOG.md)"
[ "$(git rev-list --count HEAD)" = 1 ] || failed "version committed"

# stamp-version
new_repo
git commit -q --allow-empty -m second
printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict></dict></plist>\n' >"$ROOT/Info.plist"
expect_success "stamp" "$SCRIPTS/stamp-version.sh" "$ROOT/Info.plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")" = 0.1.0 ] || failed "stamped short version"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Info.plist")" = 2 ] || failed "stamped build number"
echo 0.1 >VERSION
expect_refusal "stamp with malformed VERSION" "malformed" "$SCRIPTS/stamp-version.sh" "$ROOT/Info.plist"
shallow=$(mktemp -d "$ROOT/shallow.XXXX")
git clone -q --depth 1 "file://$PWD" "$shallow" && cd "$shallow" || exit 1
expect_refusal "stamp in a shallow clone" "shallow" "$SCRIPTS/stamp-version.sh" "$ROOT/Info.plist"
nogit=$(mktemp -d "$ROOT/nogit.XXXX")
cd "$nogit" && echo 0.1.0 >VERSION || exit 1
expect_refusal "stamp outside git" "not a git repository" "$SCRIPTS/stamp-version.sh" "$ROOT/Info.plist"

# make release: a tree after `make version V=0.2.0` and its commit passes
new_repo
"$SCRIPTS/bump-version.sh" 0.2.0 >/dev/null && commit_all
expect_success "release checks" "$SCRIPTS/release-check.sh"

git switch -qc feature
expect_refusal "release off main" "only from main" "$SCRIPTS/release-check.sh"
git switch -q main
git switch -q --detach
expect_refusal "release detached" "only from main" "$SCRIPTS/release-check.sh"
git switch -q main

echo "- Dirty" >>CHANGELOG.md
expect_refusal "release dirty tree" "not clean" "$SCRIPTS/release-check.sh"
git checkout -q CHANGELOG.md
touch untracked
expect_refusal "release untracked file" "not clean" "$SCRIPTS/release-check.sh"
rm untracked

shallow=$(mktemp -d "$ROOT/shallow.XXXX")
git clone -q --depth 1 "file://$PWD" "$shallow"
(cd "$shallow" && expect_refusal "release shallow clone" "shallow" "$SCRIPTS/release-check.sh") || failures=$((failures + 1))

git tag v0.2.0
expect_refusal "release tag exists" "tag v0.2.0 already exists" "$SCRIPTS/release-check.sh"
git tag -d v0.2.0 >/dev/null

GH_RELEASES=v0.2.0 expect_refusal "release already exists" "already exists in doubleloop-io/downtab" "$SCRIPTS/release-check.sh"

git tag v0.10.0
expect_refusal "release not greater than latest tag (numeric)" "not greater than the latest tag v0.10.0" "$SCRIPTS/release-check.sh"
git tag -d v0.10.0 >/dev/null

MAKE_TEST_EXIT=1 expect_refusal "release make test fails" "make test failed" "$SCRIPTS/release-check.sh"

new_repo
echo 0.2.0 >VERSION && commit_all
expect_refusal "release without changelog section" "no entries under ## [0.2.0]" "$SCRIPTS/release-check.sh"
printf '# Changelog\n\n## [Unreleased]\n\n## [0.2.0] - %s\n\n### Added\n\n## [0.1.0] - 2026-01-01\n\n- First thing\n' "$TODAY" >CHANGELOG.md && commit_all
expect_refusal "release with empty changelog section" "no entries under ## [0.2.0]" "$SCRIPTS/release-check.sh"

# release notes: the version's section without its heading
new_repo
printf '# Changelog\n\n## [Unreleased]\n\n## [0.2.0] - 2026-02-01\n\n### Added\n\n- New thing\n\n### Fixed\n\n- Old bug\n\n## [0.1.0] - 2026-01-01\n\n- First thing\n' >CHANGELOG.md
notes=$(source "$SCRIPTS/lib/version.sh" && changelog_section 0.2.0)
[ "$notes" = "$(printf '### Added\n\n- New thing\n\n### Fixed\n\n- Old bug')" ] || failed "changelog section: $notes"

# appcast: a built app at the bumped version, its DMG signed for Sparkle
# fake_app <version> <build>: a bundle with just the Info.plist keys appcast.sh reads.
fake_app() {
  local app=$ROOT/app.$RANDOM/Downtab.app
  mkdir -p "$app/Contents"
  plutil -create xml1 "$app/Contents/Info.plist"
  plutil -insert CFBundleShortVersionString -string "$1" "$app/Contents/Info.plist"
  plutil -insert CFBundleVersion -string "$2" "$app/Contents/Info.plist"
  plutil -insert LSMinimumSystemVersion -string 15.0 "$app/Contents/Info.plist"
  plutil -insert SUPublicEDKey -string "$TEST_KEY" "$app/Contents/Info.plist"
  echo "$app"
}

new_repo
"$SCRIPTS/bump-version.sh" 0.2.0 >/dev/null && commit_all
app=$(fake_app 0.2.0 42)
printf 'twelve bytes' >"$ROOT/Downtab.dmg"
expect_success "appcast" "$SCRIPTS/appcast.sh" "$app" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
appcast_item() { appcast_value "$ROOT/appcast.xml" "//*[local-name()=\"item\"]/$1"; }
appcast_value() { xmllint --xpath "string($2)" "$1"; }
[ "$(appcast_item '*[local-name()="version"]')" = 42 ] || failed "appcast build: $(appcast_item '*[local-name()="version"]')"
[ "$(appcast_item '*[local-name()="shortVersionString"]')" = 0.2.0 ] || failed "appcast version"
[ "$(appcast_item '*[local-name()="minimumSystemVersion"]')" = 15.0 ] || failed "appcast minimum system"
[ "$(appcast_item '*[local-name()="hardwareRequirements"]')" = arm64 ] || failed "appcast hardware requirements"
[ "$(appcast_item 'description/@*[local-name()="format"]')" = markdown ] || failed "appcast notes format"
[ "$(appcast_item description)" = "$(printf '### Added\n\n- New thing\n')" ] || failed "appcast notes: $(appcast_item description)"
[ "$(appcast_item enclosure/@url)" = https://github.com/doubleloop-io/downtab/releases/download/v0.2.0/Downtab.dmg ] \
  || failed "appcast url: $(appcast_item enclosure/@url)"
[ "$(appcast_item enclosure/@length)" = 12 ] || failed "appcast length: $(appcast_item enclosure/@length)"
[ "$(appcast_item 'enclosure/@*[local-name()="edSignature"]')" = "$SIGNATURE" ] || failed "appcast signature"

rm "$ROOT/appcast.xml"
expect_refusal "appcast for an app of another version" "is 0.1.0, VERSION is 0.2.0" \
  "$SCRIPTS/appcast.sh" "$(fake_app 0.1.0 41)" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
SPARKLE_KEY=other-key expect_refusal "appcast with a key not matching the app" "not $app's SUPublicEDKey" \
  "$SCRIPTS/appcast.sh" "$app" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
SIGN_VERIFY_EXIT=1 expect_refusal "appcast with a signature that does not verify" "does not verify" \
  "$SCRIPTS/appcast.sh" "$app" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
[ ! -e "$ROOT/appcast.xml" ] || failed "a refused appcast was written"

# release publishing: tags, pushes the tag, creates the release with the DMG, the Appcast and the notes
new_repo
"$SCRIPTS/bump-version.sh" 0.2.0 >/dev/null && commit_all
origin=$(mktemp -d "$ROOT/origin.XXXX")
git init -q --bare "$origin" && git remote add origin "$origin"
rm -f "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
expect_refusal "publish without DMG" "Downtab.dmg missing" "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
touch "$ROOT/Downtab.dmg"
expect_refusal "publish without appcast" "appcast.xml missing" \
  "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
printf '<rss><channel><item><shortVersionString>0.1.0</shortVersionString></item></channel></rss>\n' >"$ROOT/appcast.xml"
expect_refusal "publish with a stale appcast" "does not offer 0.2.0" \
  "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
"$SCRIPTS/appcast.sh" "$(fake_app 0.2.0 42)" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml" >/dev/null
expect_success "publish" "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"
git -C "$origin" rev-parse --quiet --verify refs/tags/v0.2.0 >/dev/null || failed "publish did not push tag v0.2.0"
[ "$(cat "$ROOT/gh-create")" = "release create v0.2.0 $ROOT/Downtab.dmg $ROOT/appcast.xml --repo doubleloop-io/downtab --title Downtab 0.2.0 --notes-file $(sed -n 's/.*--notes-file //p' "$ROOT/gh-create")" ] \
  || failed "publish gh arguments: $(cat "$ROOT/gh-create")"
[ "$(cat "$ROOT/gh-notes")" = "$(printf '### Added\n\n- New thing')" ] || failed "publish notes: $(cat "$ROOT/gh-notes")"
[ "$(cat "$ROOT/gh-workflow")" = "workflow run pages.yml --repo doubleloop-io/downtab --ref main" ] \
  || failed "publish did not redeploy the website: $(cat "$ROOT/gh-workflow" 2>/dev/null)"

new_repo
"$SCRIPTS/bump-version.sh" 0.2.0 >/dev/null && commit_all
origin=$(mktemp -d "$ROOT/origin.XXXX")
git init -q --bare "$origin" && git remote add origin "$origin"
GH_CREATE_EXIT=1 expect_refusal "publish when gh fails" "gh release create v0.2.0 $ROOT/Downtab.dmg $ROOT/appcast.xml" \
  "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.dmg" "$ROOT/appcast.xml"

# make ship: a repo whose main matches a bare origin
new_shipping_repo() {
  new_repo
  origin=$(mktemp -d "$ROOT/origin.XXXX")
  git init -q --bare -b main "$origin" && git remote add origin "$origin" && git push -q origin main
  rm -f "$ROOT/make-calls"
}

# Nothing changed locally or on origin, and neither smoke nor release ran unless listed.
expect_untouched() {
  local name=$1 calls=${2:-}
  [ "$(cat VERSION)" = 0.1.0 ] || failed "$name: VERSION changed"
  [ -z "$(git status --porcelain)" ] || failed "$name: tree changed"
  [ "$(git rev-list --count HEAD)" = 1 ] || failed "$name: committed"
  [ "$(git -C "$origin" rev-list --count main)" = 1 ] || failed "$name: pushed"
  [ "$(tr '\n' ' ' 2>/dev/null <"$ROOT/make-calls")" = "$calls" ] \
    || failed "$name: make calls '$(tr '\n' ' ' 2>/dev/null <"$ROOT/make-calls")', expected '$calls'"
}

new_shipping_repo
expect_refusal "ship without V" "usage" "$SCRIPTS/ship.sh"
expect_refusal "ship V=1.2" "not X.Y.Z" "$SCRIPTS/ship.sh" 1.2
expect_refusal "ship V not greater than VERSION" "not greater than the current version" "$SCRIPTS/ship.sh" 0.1.0
git tag v0.3.0
expect_refusal "ship V not greater than latest tag" "not greater than the latest tag v0.3.0" "$SCRIPTS/ship.sh" 0.2.0
git tag -d v0.3.0 >/dev/null
git switch -qc feature
expect_refusal "ship off main" "only from main" "$SCRIPTS/ship.sh" 0.2.0
git switch -q main
touch untracked
expect_refusal "ship dirty tree" "not clean" "$SCRIPTS/ship.sh" 0.2.0
rm untracked
expect_untouched "ship refusals"

new_shipping_repo
git commit -q --allow-empty -m unpushed
expect_refusal "ship ahead of origin" "differs from origin/main" "$SCRIPTS/ship.sh" 0.2.0
git reset -q --hard HEAD~1
other=$(mktemp -d "$ROOT/other.XXXX")
git clone -q "$origin" "$other" && git -C "$other" commit -q --allow-empty -m elsewhere && git -C "$other" push -q origin main
expect_refusal "ship behind origin" "differs from origin/main" "$SCRIPTS/ship.sh" 0.2.0

new_shipping_repo
MAKE_TEST_EXIT=1 expect_refusal "ship make test fails" "make test failed" "$SCRIPTS/ship.sh" 0.2.0
expect_untouched "ship make test fails" "test "

new_shipping_repo
MAKE_SMOKE_EXIT=1 expect_refusal "ship make smoke fails" "make smoke failed" "$SCRIPTS/ship.sh" 0.2.0
expect_untouched "ship make smoke fails" "test smoke "

new_shipping_repo
MAKE_NOTARIZE_EXIT=1 expect_refusal "ship notarize-check fails" "make notarize-check failed" "$SCRIPTS/ship.sh" 0.2.0
expect_untouched "ship notarize-check fails" "test smoke notarize-check "

# release preflight: checked by ship before anything runs or changes
new_shipping_repo
SIGNING_IDENTITY="Apple Development: someone (ABCDE12345)" \
  expect_refusal "ship without the Developer ID identity" "signing identity missing" "$SCRIPTS/ship.sh" 0.2.0
NOTARY_EXIT=69 expect_refusal "ship without notary credentials" "notary credentials unusable" "$SCRIPTS/ship.sh" 0.2.0
GH_AUTH_EXIT=1 expect_refusal "ship with gh logged out" "gh is not authenticated" "$SCRIPTS/ship.sh" 0.2.0
SPARKLE_BIN="$ROOT/nowhere" expect_refusal "ship without Sparkle's tools" "Sparkle tools missing" "$SCRIPTS/ship.sh" 0.2.0
GENERATE_KEYS_EXIT=1 expect_refusal "ship without the Sparkle key" "Sparkle private key missing" "$SCRIPTS/ship.sh" 0.2.0
SPARKLE_KEY=other-key expect_refusal "ship with a Sparkle key not matching the app" "is not SUPublicEDKey" \
  "$SCRIPTS/ship.sh" 0.2.0
SIGN_EXIT=1 expect_refusal "ship when sign_update cannot sign" "sign_update cannot sign" "$SCRIPTS/ship.sh" 0.2.0
GH_PUSH=false expect_refusal "ship without push permission" "no push permission on doubleloop-io/downtab" \
  "$SCRIPTS/ship.sh" 0.2.0
expect_untouched "ship preflight refusals"

new_shipping_repo
MAKE_RELEASE_EXIT=1 expect_refusal "ship release fails after the push" "fix the cause, then make release" \
  "$SCRIPTS/ship.sh" 0.2.0
[ "$(git -C "$origin" rev-parse main)" = "$(git rev-parse HEAD)" ] || failed "ship release fails: main not pushed"

new_shipping_repo
expect_success "ship" "$SCRIPTS/ship.sh" 0.2.0
[ "$(cat VERSION)" = 0.2.0 ] || failed "ship VERSION: $(cat VERSION)"
[ -z "$(git status --porcelain)" ] || failed "ship left changes: $(git status --porcelain)"
[ "$(git log -1 --format=%s)" = "Release v0.2.0" ] || failed "ship commit message: $(git log -1 --format=%s)"
[ "$(git show --name-only --format= HEAD | sort | tr '\n' ' ')" = "CHANGELOG.md VERSION " ] \
  || failed "ship committed: $(git show --name-only --format= HEAD)"
[ "$(git -C "$origin" rev-parse main)" = "$(git rev-parse HEAD)" ] || failed "ship did not push main"
[ "$(tr '\n' ' ' <"$ROOT/make-calls")" = "test smoke notarize-check release " ] || failed "ship make calls: $(cat "$ROOT/make-calls")"

if [ "$failures" -gt 0 ]; then echo "versioning: $failures failed"; exit 1; fi
echo "versioning ok"
