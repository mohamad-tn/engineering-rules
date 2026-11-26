#!/usr/bin/env bash
# Print the path of a pinned tool binary. Uses the one on PATH when present;
# otherwise installs the pinned release (version and SHA-256 come from
# .github/tool-pins.env or the environment). Supported: gitleaks, lychee
# (Linux x64 downloads; on other systems install the tool with your package
# manager so it is on PATH).
# Usage: ensure-tool.sh gitleaks|lychee
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

tool="${1:?usage: ensure-tool.sh gitleaks|lychee}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cache="${TOOLS_DIR:-${HOME}/.cache/engineering-rules-skill/tools}"

if command -v "$tool" >/dev/null 2>&1; then
  command -v "$tool"
  exit 0
fi

case "$tool" in
  gitleaks)
    version="${GITLEAKS_VERSION:-}"
    sha="${GITLEAKS_SHA256:-}"
    url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_x64.tar.gz"
    member="gitleaks"
    strip=0
    ;;
  lychee)
    version="${LYCHEE_VERSION:-}"
    sha="${LYCHEE_SHA256:-}"
    url="https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-x86_64-unknown-linux-gnu.tar.gz"
    member="lychee-x86_64-unknown-linux-gnu/lychee"
    strip=1
    ;;
  *)
    echo "ensure-tool: unknown tool '${tool}'" >&2
    exit 2
    ;;
esac

if [[ -z "$version" || -z "$sha" ]]; then
  echo "ensure-tool: ${tool} is not on PATH and no pin is set." >&2
  echo "  Install it, or fill the version and SHA-256 in .github/tool-pins.env." >&2
  exit 1
fi

bin="${cache}/${tool}-${version}/${tool}"
if [[ ! -x "$bin" ]]; then
  bash "${here}/install-release-tool.sh" "$url" "$sha" "$member" "${cache}/${tool}-${version}" "$strip" >&2
fi
echo "$bin"
