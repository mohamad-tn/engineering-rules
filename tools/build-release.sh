#!/usr/bin/env bash
# Builds the release archives in dist/.
#   bash tools/build-release.sh <version>      e.g. 1.0.0 or v1.0.0
# One zip per edition of the skill (English, and Arabic when present) plus SHA256SUMS.
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi
version="${1:?usage: build-release.sh <version>}"
version="${version#v}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${root}/dist"
rm -rf "$dist"
mkdir -p "$dist"
for skill in engineering-rules engineering-rules-ar; do
  [[ -d "${root}/skills/${skill}" ]] || continue
  (cd "${root}/skills" && zip -r -X -q "${dist}/${skill}-${version}.zip" "$skill" -x '*/.DS_Store')
  echo "built ${skill}-${version}.zip"
done
(cd "$dist" && { if command -v sha256sum >/dev/null 2>&1; then sha256sum ./*.zip; else shasum -a 256 ./*.zip; fi; } | sed 's#\./##' >SHA256SUMS)
echo "wrote dist/SHA256SUMS"
