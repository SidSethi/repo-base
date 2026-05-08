# repo-base

`repo-base` keeps local repository and documentation context in one predictable
place for human and AI-assisted work.

It has two jobs:

- Turn a GitHub URL into a local checkout with a printed path and commit SHA.
- Refresh a durable cache of pinned repos and flat docs.

## Layout

Default root:

```text
~/repo-base/
├── repos/<owner>/<repo>/   # durable cache, refreshed destructively
├── tmp/<owner>/<repo>/     # per-task checkouts, refreshed only when clean
├── docs/...                # flat docs such as llms-full.txt
└── docs.txt                # tab-separated flat-doc manifest
```

Set `REPO_BASE=/path/to/base` to use a different root.

The `repos` and `tmp` split is intentional. Durable repos are cache entries and
can be reset during refresh. Temporary checkouts may contain task-local edits, so
they are skipped when dirty.

## Usage

Temporary checkout:

```sh
repo-base https://github.com/owner/repo
```

Durable checkout:

```sh
repo-base --pin https://github.com/owner/repo
```

Refresh durable repos and flat docs:

```sh
repo-base refresh
```

Output from a checkout is prompt-friendly:

```text
path:       /Users/sid/repo-base/tmp/owner/repo
sha:        d4e5f6abc123...
ref:        v1.2.3
submodules: none
```

`ref:` appears only when a release or tag was selected.

## Ref Selection

By default, `repo-base` tries to clone a stable public ref:

1. Latest GitHub release.
2. Latest tag, if there are no releases.
3. Default branch HEAD, if there are no releases or tags.

Use `--latest-commit` to skip release and tag lookup.

## Flat Docs

`repo-base refresh` reads `$REPO_BASE/docs.txt` when present. Each non-comment
row is:

```text
https://example.com/llms-full.txt	docs/example-llms-full.txt
```

The second field must be a relative path under `REPO_BASE`.

## Install

From the checkout:

```sh
./install.sh
```

For dotfiles-managed wrappers:

```sh
./install.sh --bin-dir ~/.dotfiles/bin --repo-dir '$HOME/code/repo-base'
```

The installer writes only a small operational wrapper. Implementation,
documentation, and tests stay in this repo.

## Development

```sh
./test.sh
shellcheck repo-base install.sh test.sh
bash -n repo-base install.sh test.sh
```
