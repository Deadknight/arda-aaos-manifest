#!/bin/bash
set -Eeuo pipefail

ROOT="${1:-$(pwd)}"
BUNDLE_ROOT="${BUNDLE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$BUNDLE_ROOT/metadata/release.env"

fail() { echo "FAIL=$1" >&2; exit 2; }

[[ -d "$ROOT/.repo" ]] || fail "not a repo checkout: $ROOT"

echo "=== ARDA RELEASE REAPPLY ==="
echo "ROOT=$ROOT"
echo "RELEASE_ID=$RELEASE_ID"

# Exact-lock all non-ARDA repo-managed projects and frameworks/base parent.
python3 - "$ROOT" "$BUNDLE_ROOT/locks/base-projects.tsv" <<'PY'
from pathlib import Path
import csv, subprocess, sys

root=Path(sys.argv[1])
lock=Path(sys.argv[2])

def run(args,cwd=None,check=True):
    p=subprocess.run(args,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if check and p.returncode:
        raise RuntimeError(f"rc={p.returncode}: {' '.join(args)}\n{p.stderr}")
    return p

rows=list(csv.DictReader(lock.open(),delimiter="\t"))
for i,r in enumerate(rows,1):
    p=root/r["path"]
    if not p.exists():
        raise RuntimeError(f"missing project {r['path']}")
    sha=r["sha"]
    if run(["git","cat-file","-e",f"{sha}^{{commit}}"],cwd=p,check=False).returncode:
        run(["git","fetch","--no-tags",r["fetch_url"],sha],cwd=p)
    run(["git","checkout","-q","--detach",sha],cwd=p)
    run(["git","reset","--hard","-q",sha],cwd=p)
    if i % 100 == 0:
        print(f"BASE_LOCK_PROGRESS={i}/{len(rows)}")
print(f"BASE_PROJECT_LOCK=PASS count={len(rows)}")
PY

ensure_custom() {
  local path="$1" sha="$2" url="$3" mode="$4"
  local full="$ROOT/$path"

  if git -C "$full" rev-parse --git-dir >/dev/null 2>&1; then
    :
  else
    if [[ "$mode" != "existing-or-clone" ]]; then
      fail "custom repo missing: $path"
    fi
    if [[ -e "$full" ]]; then
      # A fresh checkout may contain an empty directory, but never overwrite content.
      if [[ -d "$full" && -z "$(find "$full" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        rmdir "$full"
      else
        fail "non-git path blocks custom clone: $path"
      fi
    fi
    mkdir -p "$(dirname "$full")"
    git clone --quiet --filter=blob:none --no-checkout "$url" "$full"
  fi

  if ! git -C "$full" cat-file -e "${sha}^{commit}" 2>/dev/null; then
    git -C "$full" fetch --no-tags "$url" "$sha"
  fi

  git -C "$full" checkout -q --detach "$sha"
  git -C "$full" reset --hard -q "$sha"

  actual="$(git -C "$full" rev-parse HEAD)"
  [[ "$actual" == "$sha" ]] || fail "custom HEAD mismatch: $path"

  status="$(git -C "$full" status --porcelain=v1 --untracked-files=all)"
  [[ -z "$status" ]] || fail "custom repo dirty after restore: $path"

  echo "CUSTOM_RESTORE=PASS path=$path sha=$sha"
}

# vendor/arda must exist before frameworks/base overlay is applied.
vendor_line="$(awk -F '\t' '$1=="vendor/arda"{print; exit}' "$BUNDLE_ROOT/locks/custom-repos.tsv")"
IFS=$'\t' read -r vendor_path vendor_sha vendor_url vendor_mode <<< "$vendor_line"
ensure_custom "$vendor_path" "$vendor_sha" "$vendor_url" "$vendor_mode"

# Restore all other custom repositories except nested vendor children for now.
tail -n +2 "$BUNDLE_ROOT/locks/custom-repos.tsv" |
while IFS=$'\t' read -r path sha url mode; do
  case "$path" in
    vendor/arda|vendor/arda/ardaplatform|vendor/arda/proprietary) continue ;;
  esac
  ensure_custom "$path" "$sha" "$url" "$mode"
done

# Produce the deterministic local frameworks/base commit from vendor/arda recipe.
"$ROOT/vendor/arda/release/overlays/frameworks-base/apply.sh" "$ROOT"

# Restore nested independent vendor repositories.
tail -n +2 "$BUNDLE_ROOT/locks/custom-repos.tsv" |
while IFS=$'\t' read -r path sha url mode; do
  case "$path" in
    vendor/arda/ardaplatform|vendor/arda/proprietary)
      ensure_custom "$path" "$sha" "$url" "$mode"
      ;;
  esac
done

echo "ARDA_RELEASE_REAPPLY=PASS"
