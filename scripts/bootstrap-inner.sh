#!/bin/bash
set -Eeuo pipefail

TARGET="${1:-$HOME/aosp-rpi-aaos16}"
BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BUNDLE_ROOT/metadata/release.env"

fail() { echo "FAIL=$1" >&2; exit 2; }

for cmd in git curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || fail "$cmd is required"
done

if [[ -e "$TARGET" ]]; then
  [[ -d "$TARGET" ]] || fail "target exists and is not a directory: $TARGET"
  [[ -z "$(find "$TARGET" -mindepth 1 -maxdepth 1 -print -quit)" ]] \
    || fail "target must be empty for bootstrap: $TARGET"
else
  mkdir -p "$TARGET"
fi

TOOLS="$TARGET/.arda-tools"
mkdir -p "$TOOLS"
REPO_BIN="$TOOLS/repo"

curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$REPO_BIN"
chmod +x "$REPO_BIN"

cd "$TARGET"

echo "=== ARDA AAOS16 BOOTSTRAP ==="
echo "TARGET=$TARGET"
echo "RELEASE_ID=$RELEASE_ID"
echo "AOSP_MANIFEST_COMMIT=$AOSP_MANIFEST_COMMIT"

# repo accepts a manifest revision for -b; use the exact audited manifest commit.
"$REPO_BIN" init \
  -u "$AOSP_MANIFEST_URL" \
  -b "$AOSP_MANIFEST_COMMIT"

actual_manifest="$(git -C .repo/manifests rev-parse HEAD)"
[[ "$actual_manifest" == "$AOSP_MANIFEST_COMMIT" ]] \
  || fail "repo init did not pin requested manifest commit"

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
cp "$BUNDLE_ROOT/manifests/10-remove_projects.xml" .repo/local_manifests/
cp "$BUNDLE_ROOT/manifests/20-manifest_brcm_rpi.xml" .repo/local_manifests/

jobs="${ARDA_SYNC_JOBS:-}"
if [[ -z "$jobs" ]]; then
  n="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
  (( n > 12 )) && n=12
  (( n < 1 )) && n=1
  jobs="$n"
fi

echo "REPO_SYNC_JOBS=$jobs"
"$REPO_BIN" sync -j"$jobs" --no-tags

actual_manifest="$(git -C .repo/manifests rev-parse HEAD)"
[[ "$actual_manifest" == "$AOSP_MANIFEST_COMMIT" ]] \
  || fail "manifest commit moved during sync"

# Keep a local immutable copy of release tooling in the target checkout.
rm -rf "$TARGET/.arda-release"
mkdir -p "$TARGET/.arda-release"
(
  cd "$BUNDLE_ROOT"
  tar --exclude=.git -cf - .
) | (
  cd "$TARGET/.arda-release"
  tar -xf -
)

BUNDLE_ROOT="$TARGET/.arda-release" \
  "$TARGET/.arda-release/scripts/reapply.sh" "$TARGET"

BUNDLE_ROOT="$TARGET/.arda-release" \
  "$TARGET/.arda-release/scripts/verify-inner.sh" "$TARGET"

echo
echo "=== FINAL ==="
echo "ARDA_AAOS16_BOOTSTRAP=PASS"
echo "TARGET=$TARGET"
echo "PI5: cd '$TARGET' && source build/envsetup.sh && lunch $PI5_LUNCH"
echo "PI4: cd '$TARGET' && source build/envsetup.sh && lunch $PI4_LUNCH"
echo "BUILD_NOT_STARTED=YES"
