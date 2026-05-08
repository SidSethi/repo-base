#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$ROOT/repo-base"

pass_count=0
fail_count=0
workdir=""

cleanup() {
  if [[ -n "$workdir" && -d "$workdir" ]]; then
    rm -rf "$workdir"
  fi
}
trap cleanup EXIT

fail() {
  echo "not ok - $1" >&2
  fail_count=$((fail_count + 1))
}

pass() {
  echo "ok - $1"
  pass_count=$((pass_count + 1))
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label"
    printf 'expected to contain: %s\nactual:\n%s\n' "$needle" "$haystack" >&2
  fi
}

assert_file() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    pass "$label"
  else
    fail "$label"
    printf 'missing file: %s\n' "$path" >&2
  fi
}

assert_not_file() {
  local path="$1" label="$2"
  if [[ ! -f "$path" ]]; then
    pass "$label"
  else
    fail "$label"
    printf 'unexpected file: %s\n' "$path" >&2
  fi
}

make_commit() {
  local repo="$1" name="$2" content="$3"
  printf '%s\n' "$content" > "$repo/$name"
  git -C "$repo" add "$name"
  git -C "$repo" commit -m "Update $name" --quiet
}

make_remote() {
  local owner="$1" repo="$2"
  local src="$workdir/src/$owner/$repo"
  local remote="$workdir/remotes/$owner/$repo"

  mkdir -p "$src" "$(dirname "$remote")"
  git -C "$src" init --quiet
  git -C "$src" config user.name "repo-base test"
  git -C "$src" config user.email "repo-base-test@example.invalid"
  make_commit "$src" README.md "initial"
  git -C "$src" clone --bare --quiet "$src" "$remote"
  printf '%s\n' "$src"
}

run_base() {
  HOME="$workdir/home" \
    GIT_CONFIG_GLOBAL="$workdir/gitconfig" \
    REPO_BASE="$workdir/home/repo-base" \
    "$SCRIPT" --latest-commit "$@"
}

workdir="$(mktemp -d "${TMPDIR:-/tmp}/repo-base-test.XXXXXX")"
mkdir -p "$workdir/home"

git config --file "$workdir/gitconfig" url."file://$workdir/remotes/".insteadOf "https://github.com/"
git config --file "$workdir/gitconfig" protocol.file.allow always

src="$(make_remote acme sample)"

output="$(run_base "https://github.com/acme/sample")"
assert_contains "$output" "path:       $workdir/home/repo-base/tmp/acme/sample" "temporary checkout prints target path"
assert_contains "$output" "sha:        " "checkout prints sha"
assert_contains "$output" "submodules: none" "checkout reports no submodules"
assert_file "$workdir/home/repo-base/tmp/acme/sample/README.md" "temporary checkout creates clone"

make_commit "$src" SECOND.md "second"
git -C "$src" push --quiet "file://$workdir/remotes/acme/sample" HEAD:main
output="$(run_base "https://github.com/acme/sample")"
assert_file "$workdir/home/repo-base/tmp/acme/sample/SECOND.md" "clean temporary rerun refreshes checkout"

printf 'local edit\n' > "$workdir/home/repo-base/tmp/acme/sample/LOCAL.md"
make_commit "$src" THIRD.md "third"
git -C "$src" push --quiet "file://$workdir/remotes/acme/sample" HEAD:main
stderr="$workdir/dirty.stderr"
output="$(run_base "https://github.com/acme/sample" 2>"$stderr")"
assert_contains "$(cat "$stderr")" "has local modifications - skipping refresh" "dirty temporary rerun warns"
assert_not_file "$workdir/home/repo-base/tmp/acme/sample/THIRD.md" "dirty temporary rerun leaves checkout unchanged"

output="$(run_base --pin "https://github.com/acme/sample")"
assert_contains "$output" "path:       $workdir/home/repo-base/repos/acme/sample" "pin clone prints durable path"
printf 'local pin edit\n' > "$workdir/home/repo-base/repos/acme/sample/LOCAL.md"
output="$(run_base --pin "https://github.com/acme/sample")"
assert_not_file "$workdir/home/repo-base/repos/acme/sample/LOCAL.md" "pin rerun force-cleans local changes"

sub_src="$(make_remote acme with-submodules)"
printf '%s\n' \
  '[submodule "vendor/lib"]' \
  '	path = vendor/lib' \
  '	url = https://github.com/acme/lib' \
  > "$sub_src/.gitmodules"
git -C "$sub_src" add .gitmodules
git -C "$sub_src" commit -m "Add submodule metadata" --quiet
git -C "$sub_src" push --quiet "file://$workdir/remotes/acme/with-submodules" HEAD:main
output="$(run_base "https://github.com/acme/with-submodules")"
assert_contains "$output" "submodules: DETECTED" "submodule metadata is detected"
assert_contains "$output" "vendor/lib" "submodule paths are listed"

if "$SCRIPT" "not-a-github-url" >"$workdir/invalid.out" 2>"$workdir/invalid.err"; then
  fail "invalid URL exits nonzero"
else
  pass "invalid URL exits nonzero"
fi
assert_contains "$(cat "$workdir/invalid.err")" "unrecognized GitHub URL format" "invalid URL prints useful error"

make_commit "$src" FOURTH.md "fourth"
git -C "$src" push --quiet "file://$workdir/remotes/acme/sample" HEAD:main
printf 'local pin edit\n' > "$workdir/home/repo-base/repos/acme/sample/LOCAL.md"
mkdir -p "$workdir/doc-source"
printf 'doc body\n' > "$workdir/doc-source/source.md"
printf '%s\t%s\n' "file://$workdir/doc-source/source.md" "docs/source.md" > "$workdir/home/repo-base/docs.txt"

output="$(
  HOME="$workdir/home" \
    GIT_CONFIG_GLOBAL="$workdir/gitconfig" \
    REPO_BASE="$workdir/home/repo-base" \
    LOCKDIR="$workdir/locks/repo-base-refresh.lock" \
    "$SCRIPT" refresh
)"
assert_contains "$output" "==> Refreshing git repos in $workdir/home/repo-base/repos" "refresh scans durable repos"
assert_file "$workdir/home/repo-base/repos/acme/sample/FOURTH.md" "refresh fetches latest repo content"
assert_not_file "$workdir/home/repo-base/repos/acme/sample/LOCAL.md" "refresh discards durable cache edits"
assert_file "$workdir/home/repo-base/docs/source.md" "refresh downloads flat docs"
assert_not_file "$workdir/home/repo-base/tmp/acme/sample/THIRD.md" "refresh ignores temporary checkouts"

output="$(
  HOME="$workdir/home" \
    GIT_CONFIG_GLOBAL="$workdir/gitconfig" \
    REPO_BASE="$workdir/home/repo-base" \
    "$SCRIPT" ls
)"
assert_contains "$output" "Pinned repos" "ls prints pinned repos section"
assert_contains "$output" "acme/sample" "ls includes pinned repo"
assert_contains "$output" "Pinned docs" "ls prints pinned docs section"
assert_contains "$output" "DOCUMENT" "ls prints pinned docs header"
assert_contains "$output" "REFRESHED" "ls prints pinned docs refresh date header"
assert_contains "$output" "docs/source.md" "ls includes refreshed pinned doc"
assert_contains "$output" "Tmp checkouts: 2" "ls prints temporary checkout count"

"$ROOT/install.sh" --bin-dir "$workdir/install-bin" --repo-dir "$ROOT" >/dev/null
assert_file "$workdir/install-bin/repo-base" "install writes repo-base wrapper"
if "$workdir/install-bin/repo-base" not-a-github-url >"$workdir/install.out" 2>"$workdir/install.err"; then
  fail "installed wrapper exits nonzero for invalid URL"
else
  pass "installed wrapper dispatches to repo-base"
fi
HOME="$workdir/home" REPO_BASE="$workdir/empty-base" DOCS_MANIFEST="$workdir/no-docs.txt" \
  "$workdir/install-bin/repo-base" refresh >/dev/null
pass "installed wrapper dispatches refresh"

echo
echo "$pass_count passed, $fail_count failed"
[[ "$fail_count" -eq 0 ]]
