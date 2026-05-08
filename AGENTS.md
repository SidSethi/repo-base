# Agent Instructions

This repository owns the `repo-base` implementation, docs, installer, and tests.

## Scope

- Keep user-specific operational wrappers outside this repo.
- Do not add compatibility wrappers for old command names unless explicitly
  requested.
- Do not assume `~/repo-base` or `~/bin` exist in tests. Use temporary
  directories and environment overrides.

## Verification

Run these before handing off behavior changes:

```sh
./test.sh
shellcheck repo-base install.sh test.sh
bash -n repo-base install.sh test.sh
```

Tests should avoid GitHub network access. Prefer local bare repositories and Git
URL rewriting for clone and refresh coverage.
