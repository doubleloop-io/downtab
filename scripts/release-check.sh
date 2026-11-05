#!/usr/bin/env bash
# Refuses a release that is not built from a clean, full main, was not bumped, or has no release notes.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"

version=$(read_version)
tag=v$version

[ "$(git symbolic-ref --quiet --short HEAD || true)" = main ] || fail "release only from main"
[ -z "$(git status --porcelain)" ] || fail "working tree not clean: commit or discard the changes first"
[ "$(git rev-parse --is-shallow-repository)" = false ] || fail "shallow clone: the build number would be wrong, run git fetch --unshallow"

git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null && fail "tag $tag already exists: run make version"
highest=
for existing in $(git tag -l 'v*'); do
  candidate=${existing#v}
  is_semver "$candidate" || continue
  if [ -z "$highest" ] || version_gt "$candidate" "$highest"; then highest=$candidate; fi
done
if [ -n "$highest" ] && ! version_gt "$version" "$highest"; then
  fail "$version is not greater than the latest tag v$highest: run make version"
fi

if gh_output=$(gh release view "$tag" --repo "$RELEASE_REPO" 2>&1); then
  fail "release $tag already exists in $RELEASE_REPO: run make version"
elif [[ $gh_output != *"release not found"* ]]; then
  fail "cannot check release $tag in $RELEASE_REPO: $gh_output"
fi

[ -n "$(changelog_entries "$version")" ] || fail "$CHANGELOG_FILE has no entries under ## [$version]: run make version"

make test || fail "make test failed"
echo "release checks ok: $tag"
