#!/usr/bin/env bash
# Tests publish-site.sh against a throwaway repo; gh is stubbed, a local bare repo stands in for downtab-app.
set -uo pipefail
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
failures=0

failed() { echo "FAIL: $1"; failures=$((failures + 1)); }

# Stub: `gh repo clone <repo> <dir> -- <flags>` logs the repo to $ROOT/gh-clone and clones $ROOT/site.git into <dir>.
SITE=$ROOT/site.git
mkdir -p "$ROOT/bin"
cat >"$ROOT/bin/gh" <<STUB
#!/usr/bin/env bash
[ "\$1 \$2" = "repo clone" ] || { echo "unexpected gh \$*"; exit 1; }
echo "\$3" >"$ROOT/gh-clone"
git clone --quiet --depth 1 "file://$SITE" "\$4"
STUB
chmod +x "$ROOT/bin/gh"
export PATH="$ROOT/bin:$PATH"

# The stand-in for downtab-app: a README and an old page on main.
new_site() {
  local seed
  rm -rf "$SITE"
  git init --quiet --bare -b main "$SITE"
  seed=$(mktemp -d "$ROOT/seed.XXXX")
  git -C "$seed" init --quiet -b main
  echo readme >"$seed/README.md"
  echo old >"$seed/index.html"
  git -C "$seed" add . && git -C "$seed" commit --quiet -m init && git -C "$seed" push --quiet "$SITE" main
}

# A repo on main with the download page in website/; everything committed.
new_repo() {
  local repo
  repo=$(mktemp -d "$ROOT/repo.XXXX")
  cd "$repo" || exit 1
  git init --quiet -b main
  mkdir website
  echo '<html>page</html>' >website/downtab-landing.html
  echo screenshot >website/downtab-landing-screenshot.jpg
  git add . && git commit --quiet -m init
}

site_commits() { git -C "$SITE" rev-list --count main; }
site_file() { git -C "$SITE" show "main:$1"; }

# expect_refusal <name> <message fragment> <command...>
expect_refusal() {
  local name=$1 fragment=$2 output
  shift 2
  if output=$("$@" 2>&1); then failed "$name: succeeded, expected refusal"; return; fi
  [[ $output == *"$fragment"* ]] || failed "$name: expected '$fragment', got: $output"
}

# expect_output <name> <output fragment> <command...>
expect_output() {
  local name=$1 fragment=$2 output
  shift 2
  if ! output=$("$@" 2>&1); then failed "$name: $output"; return; fi
  [[ $output == *"$fragment"* ]] || failed "$name: expected '$fragment', got: $output"
}

# refusals leave the site untouched
new_site
new_repo
git switch --quiet -c feature
expect_refusal "publish off main" "only from main" "$SCRIPTS/publish-site.sh"
git switch --quiet main
git switch --quiet --detach
expect_refusal "publish detached" "only from main" "$SCRIPTS/publish-site.sh"
git switch --quiet main
echo changed >>website/downtab-landing.html
expect_refusal "publish dirty tree" "not clean" "$SCRIPTS/publish-site.sh"
git checkout --quiet website/downtab-landing.html
touch untracked
expect_refusal "publish untracked file" "not clean" "$SCRIPTS/publish-site.sh"
rm untracked
[ "$(site_commits)" = 1 ] || failed "refused publish committed to the site"

# a changed page: one commit with the two files, pushed; other files untouched
expect_output "publish changed page" "site published: https://iacoware.github.io/downtab-app/" "$SCRIPTS/publish-site.sh"
[ "$(cat "$ROOT/gh-clone")" = iacoware/downtab-app ] || failed "cloned repo: $(cat "$ROOT/gh-clone")"
[ "$(site_commits)" = 2 ] || failed "site commits after publish: $(site_commits)"
[ "$(git -C "$SITE" log -1 --format=%s main)" = "Update download page from downtab $(git rev-parse --short HEAD)" ] \
  || failed "site commit message: $(git -C "$SITE" log -1 --format=%s main)"
[ "$(git -C "$SITE" diff-tree --no-commit-id --name-only -r main | sort | tr '\n' ' ')" = "downtab-landing-screenshot.jpg index.html " ] \
  || failed "site commit files: $(git -C "$SITE" diff-tree --no-commit-id --name-only -r main)"
[ "$(site_file index.html)" = '<html>page</html>' ] || failed "published index.html: $(site_file index.html)"
[ "$(site_file downtab-landing-screenshot.jpg)" = screenshot ] || failed "published screenshot"
[ "$(site_file README.md)" = readme ] || failed "publish changed README.md"

# an unchanged page: no commit
expect_output "publish unchanged page" "site up to date" "$SCRIPTS/publish-site.sh"
[ "$(site_commits)" = 2 ] || failed "unchanged publish committed: $(site_commits) commits"

# a later change to one file is published on top
echo '<html>new</html>' >website/downtab-landing.html
git commit --quiet -am "edit page"
expect_output "publish edited page" "site published" "$SCRIPTS/publish-site.sh"
[ "$(site_commits)" = 3 ] || failed "site commits after edit: $(site_commits)"
[ "$(site_file index.html)" = '<html>new</html>' ] || failed "published edited index.html: $(site_file index.html)"

if [ "$failures" -gt 0 ]; then echo "publish-site: $failures failed"; exit 1; fi
echo "publish-site ok"
