#!/usr/bin/env bash
# Download a release archive, verify its SHA-256, and extract one member.
# Usage: install-release-tool.sh <url> <sha256> <member> <dest-dir> [strip-components]
# The checksum is mandatory: an unverified binary is never installed.
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

url="${1:?usage: install-release-tool.sh <url> <sha256> <member> <dest-dir> [strip]}"
expected="${2:?a SHA-256 is required; copy it from the release checksum file}"
member="${3:?archive member to extract}"
dest="${4:?destination directory}"
strip="${5:-0}"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl --fail --silent --show-error --location "$url" --output "$archive"

actual="$(sha256_of "$archive")"
expected="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
if [[ "$actual" != "$expected" ]]; then
  echo "::error::SHA-256 mismatch for ${url}" >&2
  echo "expected: ${expected}" >&2
  echo "actual:   ${actual}" >&2
  exit 1
fi

mkdir -p "$dest"
case "$url" in
  *.tar.gz | *.tgz) tar -xzf "$archive" -C "$dest" --strip-components="$strip" "$member" ;;
  *.tar.xz) tar -xJf "$archive" -C "$dest" --strip-components="$strip" "$member" ;;
  *.zip) unzip -q -o "$archive" "$member" -d "$dest" ;;
  *)
    echo "unsupported archive type: ${url}" >&2
    exit 1
    ;;
esac
