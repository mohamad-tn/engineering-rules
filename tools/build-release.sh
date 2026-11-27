#!/usr/bin/env bash
# Build commit-derived skill archives (not a Claude plugin bundle) in dist/.
# Usage: bash tools/build-release.sh <version|vversion> [--commit <full SHA>]
#       bash tools/build-release.sh <version|vversion> --check [--commit <full SHA>]
# Requires Python 3 and Git. Dirty, untracked and unsafe inputs fail closed.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "${root}/tools/release-package.py" --root "$root" "$@"
