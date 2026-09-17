#!/bin/bash
set -Eeuo pipefail

OWNER="${OWNER:-Deadknight}"
REPO="${REPO:-arda-aaos-manifest}"
VISIBILITY="${VISIBILITY:-}"
TARGET_NAME="Deadknight"
TARGET_EMAIL="1907606+Deadknight@users.noreply.github.com"

fail() { echo "FAIL=$1" >&2; exit 2; }

command -v git >/dev/null 2>&1 || fail "git is required"
command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is required"
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

git init -b main >/dev/null 2>&1 || true
git config user.name "$TARGET_NAME"
git config user.email "$TARGET_EMAIL"

git add -- \
  README.md bootstrap.sh verify.sh publish_to_github.sh \
  manifests locks scripts metadata

if ! git diff --cached --quiet; then
  git commit -m "release: pin ARDA AAOS16 reproducible source state"
fi

url="https://github.com/$OWNER/$REPO.git"

if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$url"
  else
    git remote add origin "$url"
  fi
else
  case "$VISIBILITY" in
    public|private) ;;
    *) fail "repo does not exist; run with VISIBILITY=public or VISIBILITY=private" ;;
  esac
  gh repo create "$OWNER/$REPO" "--$VISIBILITY" \
    --source "$ROOT" --remote origin
fi

git push -u origin main

echo "GITHUB_RELEASE_REPO_PUBLISH=PASS"
echo "REPO=$OWNER/$REPO"
