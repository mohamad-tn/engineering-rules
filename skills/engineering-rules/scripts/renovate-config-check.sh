#!/usr/bin/env bash
# Validate renovate.json strictly and check that it extends the shared preset.
# Usage: renovate-config-check.sh [repo dir]
# Env (usually from .github/tool-pins.env):
#   RENOVATE_PRESET       preset string renovate.json must extend (optional check)
#   RENOVATE_PRESET_FILE  preset file inside this repo to validate too (optional)
#   RENOVATE_VERSION      pin for the validator; required unless it is installed
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

_er_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _d in "$_er_dir" "$_er_dir/../scripts"; do
  # shellcheck source=/dev/null
  [[ -f "$_d/load-env.sh" ]] && { . "$_d/load-env.sh"; break; }
done

repo="$(cd "${1:-.}" && pwd)"
pins="${TOOL_PINS_FILE:-${repo}/.github/tool-pins.env}"
er_load_env "$pins"

preset="${RENOVATE_PRESET:-}"
if [[ ! -f "${repo}/renovate.json" ]]; then
  echo "::error file=renovate.json::renovate.json is missing." >&2
  exit 1
fi
if [[ -n "$preset" ]] && ! jq -e --arg p "$preset" '.extends | index($p) != null' "${repo}/renovate.json" >/dev/null; then
  echo "::error file=renovate.json::renovate.json must extend ${preset}." >&2
  exit 1
fi

files=(renovate.json)
if [[ -n "${RENOVATE_PRESET_FILE:-}" && -f "${repo}/${RENOVATE_PRESET_FILE}" ]]; then
  files+=("${RENOVATE_PRESET_FILE}")
fi

if command -v renovate-config-validator >/dev/null 2>&1; then
  validator=(renovate-config-validator)
else
  : "${RENOVATE_VERSION:?renovate-config-validator is not installed: pin RENOVATE_VERSION in .github/tool-pins.env}"
  validator=(npx --yes --package "renovate@${RENOVATE_VERSION}" renovate-config-validator)
fi
(cd "$repo" && "${validator[@]}" --strict --no-global "${files[@]}")
