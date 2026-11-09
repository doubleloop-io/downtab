# Sourced by the versioning scripts. Paths are relative to the repo root (the scripts' working directory).
VERSION_FILE=VERSION
CHANGELOG_FILE=CHANGELOG.md
# Hosts the releases: this repo.
RELEASE_REPO=doubleloop-io/downtab
SEMVER_PATTERN='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

fail() { echo "$*" >&2; exit 1; }

is_semver() { [[ $1 =~ $SEMVER_PATTERN ]]; }

# Numeric per component: 0.10.0 > 0.9.0.
version_gt() {
  local a b i
  IFS=. read -ra a <<<"$1"
  IFS=. read -ra b <<<"$2"
  for i in 0 1 2; do
    ((10#${a[i]} > 10#${b[i]})) && return 0
    ((10#${a[i]} < 10#${b[i]})) && return 1
  done
  return 1
}

read_version() {
  [ -f "$VERSION_FILE" ] || fail "$VERSION_FILE missing: it must hold the version, e.g. 0.1.0"
  local lines version
  lines=$(wc -l <"$VERSION_FILE" | tr -d ' ')
  version=$(head -n 1 "$VERSION_FILE")
  [ "$lines" = 1 ] && is_semver "$version" \
    || fail "$VERSION_FILE malformed: it must hold one line X.Y.Z (three integers), e.g. 0.1.0"
  echo "$version"
}

# The commit count of HEAD: it only grows because releases are built from a linear main.
build_number() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "build number unavailable: not a git repository"
  [ "$(git rev-parse --is-shallow-repository)" = false ] \
    || fail "build number unavailable: shallow clone, run git fetch --unshallow"
  git rev-list --count HEAD
}

# Prints the entry lines of a changelog section, empty when the section is missing or has none.
changelog_entries() {
  awk -v heading="## [$1]" '
    index($0, heading) == 1 { inside = 1; next }
    inside && /^## / { exit }
    inside && /^[-*] / { print }
  ' "$CHANGELOG_FILE" 2>/dev/null
}

# Prints a changelog section without its heading or surrounding blank lines: the release notes.
changelog_section() {
  awk -v heading="## [$1]" '
    index($0, heading) == 1 { inside = 1; next }
    inside && /^## / { exit }
    inside && NF { while (blanks > 0) { print ""; blanks-- } print; started = 1; next }
    inside && started { blanks++ }
  ' "$CHANGELOG_FILE" 2>/dev/null
}
