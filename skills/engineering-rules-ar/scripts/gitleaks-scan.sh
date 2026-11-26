#!/usr/bin/env bash
# Full-history secret scan of the repository in the current directory.
# Usage: gitleaks-scan.sh [config file] [gitleaks binary]
# - Every commit reachable from the checked-out refs is scanned, so a secret
#   removed in a later commit still fails (see SECRET_SCAN_FROM for legacy history).
# - A .gitleaksignore file is refused: a finding is rotated, never ignored.
# - Output is redacted so secret values never reach logs.
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

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pins="${TOOL_PINS_FILE:-.github/tool-pins.env}"
er_load_env "$pins"

config="${1:-.gitleaks.toml}"
bin="${2:-$(bash "${here}/ensure-tool.sh" gitleaks)}"

[[ -f "$config" ]] || { echo "::error::gitleaks config not found: ${config}" >&2; exit 1; }
if [[ -e .gitleaksignore ]]; then
  echo "::error file=.gitleaksignore::.gitleaksignore is not allowed. Rotate the secret instead." >&2
  exit 1
fi
if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
  echo "::error::Shallow clone. Fetch the full history (fetch-depth: 0) so every commit is scanned." >&2
  exit 1
fi

# Legacy history: an existing repository may contain old secrets that were already
# rotated. SECRET_SCAN_FROM=<commit> scans only commits after that one (record the
# decision in an ADR, and rotate the old secrets). The default scans everything.
log_opts="--all"
if [[ -n "${SECRET_SCAN_FROM:-}" ]]; then
  git cat-file -e "${SECRET_SCAN_FROM}^{commit}" 2>/dev/null || { echo "::error::SECRET_SCAN_FROM is not a commit in this clone: ${SECRET_SCAN_FROM}" >&2; exit 1; }
  log_opts="${SECRET_SCAN_FROM}..HEAD"
  echo "::warning::secret scan covers only commits after ${SECRET_SCAN_FROM} (SECRET_SCAN_FROM). History before it must be rotated and recorded in an ADR." >&2
fi

"$bin" git . --config "$config" --redact --no-banner --exit-code 1 --log-opts="$log_opts" --verbose
