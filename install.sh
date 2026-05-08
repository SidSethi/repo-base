#!/usr/bin/env bash
# Install the repo-base operational wrapper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_URL="https://github.com/SidSethi/repo-base"
BIN_DIR="$HOME/bin"
REPO_DIR="$SCRIPT_DIR"
CHECK_REPO_DIR=""
DRY_RUN=false

usage() {
  cat >&2 <<'USAGE'
Usage: install.sh [--bin-dir DIR] [--repo-dir DIR] [--check-repo-dir DIR] [--dry-run]

Installs the lightweight repo-base wrapper.

Options:
  --bin-dir DIR          Directory to write wrapper into (default: ~/bin)
  --repo-dir DIR         repo-base checkout the wrapper should execute
  --check-repo-dir DIR   Checkout path to verify before installing
  --dry-run              Print actions without writing files
USAGE
}

write_wrapper() {
  local wrapper_path="$BIN_DIR/repo-base"

  if $DRY_RUN; then
    echo "[dry-run] install wrapper: $wrapper_path -> $REPO_DIR/repo-base"
    return
  fi

  mkdir -p "$BIN_DIR"
  cat > "$wrapper_path" <<EOF
#!/usr/bin/env bash
# Wrapper for the standalone repo-base checkout.
# Usage: repo-base [--pin] [--latest-commit] <github-url>
#        repo-base refresh

set -euo pipefail

readonly SOURCE_URL="$SOURCE_URL"
readonly DEFAULT_REPO="$REPO_DIR"
readonly REPO="\${REPO_BASE_REPO:-\$DEFAULT_REPO}"
readonly SCRIPT="\$REPO/repo-base"

if [[ ! -x "\$SCRIPT" ]]; then
  cat >&2 <<EOM
error: repo-base target not found or not executable: \$SCRIPT

Clone or restore:
  git clone \$SOURCE_URL "\$DEFAULT_REPO"

Override location with:
  REPO_BASE_REPO=/path/to/repo repo-base
EOM
  exit 1
fi

exec "\$SCRIPT" "\$@"
EOF
  chmod +x "$wrapper_path"
  echo "installed: $wrapper_path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      BIN_DIR="$2"
      shift 2
      ;;
    --repo-dir)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      REPO_DIR="$2"
      shift 2
      ;;
    --check-repo-dir)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      CHECK_REPO_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

CHECK_REPO_DIR="${CHECK_REPO_DIR:-$REPO_DIR}"
CHECK_REPO_DIR="${CHECK_REPO_DIR/#\$HOME/$HOME}"
CHECK_REPO_DIR="${CHECK_REPO_DIR/#\~/$HOME}"

if [[ ! -x "$CHECK_REPO_DIR/repo-base" ]]; then
  echo "error: repo-base checkout is missing executable command: $CHECK_REPO_DIR/repo-base" >&2
  exit 1
fi

write_wrapper
