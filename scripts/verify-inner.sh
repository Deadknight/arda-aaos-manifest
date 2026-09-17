#!/bin/bash
set -Eeuo pipefail

ROOT="${1:-$(pwd)}"
BUNDLE_ROOT="${BUNDLE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$BUNDLE_ROOT/metadata/release.env"

fail() { echo "FAIL=$1" >&2; exit 2; }

[[ -d "$ROOT/.repo" ]] || fail "not a repo checkout: $ROOT"

manifest_head="$(git -C "$ROOT/.repo/manifests" rev-parse HEAD)"
[[ "$manifest_head" == "$AOSP_MANIFEST_COMMIT" ]] \
  || fail "manifest commit mismatch expected=$AOSP_MANIFEST_COMMIT actual=$manifest_head"

[[ "$(sha256sum "$ROOT/.repo/local_manifests/10-remove_projects.xml" | awk '{print $1}')" == "$REMOVE_PROJECTS_SHA256" ]] \
  || fail "remove_projects manifest SHA mismatch"

[[ "$(sha256sum "$ROOT/.repo/local_manifests/20-manifest_brcm_rpi.xml" | awk '{print $1}')" == "$RPI_MANIFEST_SHA256" ]] \
  || fail "Raspberry manifest SHA mismatch"

python3 - "$ROOT" "$BUNDLE_ROOT/locks/final-managed-projects.tsv" <<'PY'
from pathlib import Path
import csv, subprocess, sys
root=Path(sys.argv[1])
rows=list(csv.DictReader(open(sys.argv[2]),delimiter="\t"))
bad=[]
dirty=[]
for r in rows:
    p=root/r["path"]
    if not p.exists():
        bad.append((r["path"],r["sha"],"<missing>"))
        continue
    head=subprocess.run(["git","rev-parse","HEAD"],cwd=p,text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL).stdout.strip()
    if head!=r["sha"]:
        bad.append((r["path"],r["sha"],head))
    status=subprocess.run(["git","status","--porcelain=v1","--untracked-files=all"],cwd=p,text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL).stdout
    if status:
        dirty.append(r["path"])
if bad:
    for p,e,a in bad[:30]:
        print(f"HEAD_MISMATCH path={p} expected={e} actual={a}")
    raise SystemExit(f"FAIL=FINAL_MANAGED_HEAD_MISMATCH count={len(bad)}")
if dirty:
    print("\n".join(f"DIRTY path={p}" for p in dirty[:30]))
    raise SystemExit(f"FAIL=FINAL_MANAGED_DIRTY count={len(dirty)}")
print(f"FINAL_MANAGED_PROJECTS=PASS count={len(rows)}")
PY

tail -n +2 "$BUNDLE_ROOT/locks/custom-repos.tsv" |
while IFS=$'\t' read -r path sha url mode; do
  full="$ROOT/$path"
  actual="$(git -C "$full" rev-parse HEAD 2>/dev/null || true)"
  [[ "$actual" == "$sha" ]] || fail "custom mismatch path=$path expected=$sha actual=$actual"
  [[ -z "$(git -C "$full" status --porcelain=v1 --untracked-files=all)" ]] \
    || fail "custom repo dirty: $path"
done

[[ "$(git -C "$ROOT/frameworks/base" rev-parse HEAD)" == "$FRAMEWORKS_BASE_FINAL" ]] \
  || fail "frameworks/base final mismatch"
[[ "$(git -C "$ROOT/vendor/arda" rev-parse HEAD)" == "$VENDOR_ARDA_FINAL" ]] \
  || fail "vendor/arda final mismatch"

[[ -f "$ROOT/build/envsetup.sh" ]] || fail "build/envsetup.sh missing"

echo "MANIFEST_HEAD=$manifest_head"
echo "FRAMEWORKS_BASE_FINAL=$FRAMEWORKS_BASE_FINAL"
echo "VENDOR_ARDA_FINAL=$VENDOR_ARDA_FINAL"
echo "PI5_LUNCH=$PI5_LUNCH"
echo "PI4_LUNCH=$PI4_LUNCH"
echo "ARDA_RELEASE_VERIFY=PASS"
