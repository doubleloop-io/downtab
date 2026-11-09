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
# and its notes to $ROOT/gh-notes, then exits with $GH_CREATE_EXIT; `make test` exits with $MAKE_TEST_EXIT.
mkdir -p "$ROOT/bin"
cat >"$ROOT/bin/gh" <<STUB
#!/usr/bin/env bash
if [ "\$2" = create ]; then
  echo "\$*" >"$ROOT/gh-create"
  while [ \$# -gt 0 ]; do [ "\$1" = --notes-file ] && cat "\$2" >"$ROOT/gh-notes"; shift; done
  exit "\${GH_CREATE_EXIT:-0}"
fi
[[ " \${GH_RELEASES:-} " == *" \$3 "* ]] && { echo "\$3"; exit 0; }
echo "release not found"; exit 1
STUB
cat >"$ROOT/bin/make" <<'STUB'
#!/usr/bin/env bash
exit "${MAKE_TEST_EXIT:-0}"
STUB
chmod +x "$ROOT/bin/gh" "$ROOT/bin/make"
export PATH="$ROOT/bin:$PATH"

# A repo on main at VERSION 0.1.0, released as v0.1.0, with one Unreleased entry; everything committed.
new_repo() {
  local repo
  repo=$(mktemp -d "$ROOT/repo.XXXX")
  cd "$repo" || exit 1
  git init -q -b main
  echo 0.1.0 >VERSION
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

# release publishing: tags, pushes the tag, creates the release with the zip and the notes
new_repo
"$SCRIPTS/bump-version.sh" 0.2.0 >/dev/null && commit_all
origin=$(mktemp -d "$ROOT/origin.XXXX")
git init -q --bare "$origin" && git remote add origin "$origin"
expect_refusal "publish without zip" "missing" "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.zip"
touch "$ROOT/Downtab.zip"
expect_success "publish" "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.zip"
git -C "$origin" rev-parse --quiet --verify refs/tags/v0.2.0 >/dev/null || failed "publish did not push tag v0.2.0"
[ "$(cat "$ROOT/gh-create")" = "release create v0.2.0 $ROOT/Downtab.zip --repo doubleloop-io/downtab --title Downtab 0.2.0 --notes-file $(sed -n 's/.*--notes-file //p' "$ROOT/gh-create")" ] \
  || failed "publish gh arguments: $(cat "$ROOT/gh-create")"
[ "$(cat "$ROOT/gh-notes")" = "$(printf '### Added\n\n- New thing')" ] || failed "publish notes: $(cat "$ROOT/gh-notes")"

new_repo
"$SCRIPTS/bump-version.sh" 0.2.0 >/dev/null && commit_all
origin=$(mktemp -d "$ROOT/origin.XXXX")
git init -q --bare "$origin" && git remote add origin "$origin"
GH_CREATE_EXIT=1 expect_refusal "publish when gh fails" "tag v0.2.0 pushed but the release failed" \
  "$SCRIPTS/release-publish.sh" "$ROOT/Downtab.zip"

if [ "$failures" -gt 0 ]; then echo "versioning: $failures failed"; exit 1; fi
echo "versioning ok"
