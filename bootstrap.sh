#!/bin/bash
set -Eeuo pipefail

TARGET="${1:-$HOME/aosp-rpi-aaos16}"
RELEASE_REPO_URL="${ARDA_RELEASE_REPO_URL:-https://github.com/Deadknight/arda-aaos-manifest.git}"
RELEASE_REF="${ARDA_RELEASE_REF:-main}"

fail() { echo "FAIL=$1" >&2; exit 2; }

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

# Running from a cloned release repo.
if [[ -n "$SELF_DIR" && -f "$SELF_DIR/metadata/release.env" && -x "$SELF_DIR/scripts/bootstrap-inner.sh" ]]; then
  exec "$SELF_DIR/scripts/bootstrap-inner.sh" "$TARGET"
fi

# Running via: curl .../bootstrap.sh | bash -s -- /path/to/aosp
command -v git >/dev/null 2>&1 || fail "git is required"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git clone --quiet --depth 1 --branch "$RELEASE_REF" \
  "$RELEASE_REPO_URL" "$tmp/release"

exec "$tmp/release/scripts/bootstrap-inner.sh" "$TARGET"
