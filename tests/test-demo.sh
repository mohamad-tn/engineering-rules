#!/usr/bin/env bash
# The shop-api demo must keep telling the truth: BEFORE fails five gates for
# the stated reasons, AFTER passes every gate.
# shellcheck disable=SC2015
set -uo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
export TOOLS_DIR="${TOOLS_DIR:-${HOME}/.cache/engineering-rules-skill/tools}"

echo "== demo"
out="$(bash "${REPO_ROOT}/examples/shop-api/run-demo.sh" 2>&1)"; rc=$?
before="${out%%AFTER*}"
after="${out##*AFTER}"
[[ "$rc" == 0 ]] && ok "demo runs to the end" || { bad "demo rc=${rc}"; echo "$out" | tail -n 20 >&2; }
for gate in "Secret scan" "docs-check" "Policy gates" "PR size" "Stack gates"; do
  grep -q "| ${gate} .*FAIL" <<<"$before" && ok "BEFORE fails: ${gate}" || bad "BEFORE should fail ${gate}"
done
grep -q "project-dotenv-file" <<<"$before" && ok "BEFORE: tracked .env is named as the reason" || bad "dotenv reason"
grep -q 'currency code literal "USD"' <<<"$before" && ok "BEFORE: hard-coded currency is named as the reason" || bad "currency reason"
grep -q "above 800" <<<"$before" && ok "BEFORE: size is named as the reason" || bad "size reason"
if grep -q "FAIL" <<<"$after"; then bad "AFTER still has a failing gate"; echo "$after" >&2; else ok "AFTER passes every gate"; fi
[[ "$(grep -c '| PASS |' <<<"$after")" -ge 7 ]] && ok "AFTER: all seven gates report PASS" || bad "AFTER pass count"
summary
