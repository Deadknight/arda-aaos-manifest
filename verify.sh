#!/bin/bash
set -Eeuo pipefail
ROOT="${1:-$(pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/scripts/verify-inner.sh" "$ROOT"
