#!/usr/bin/env bash
# Demo: the same checkout feature, first as a typical fast pull request, then
# done to the rules. Runs the real gates on a throw-away repository.
#
#   bash examples/shop-api/run-demo.sh            # prints both runs
#   DEMO_KEEP=1 bash examples/shop-api/run-demo.sh # keep the repository, print its path
#
# Nothing here touches your own repositories. The "secret" is a harmless
# placeholder; the point is that a tracked .env file is blocked.
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill="$(cd "${here}/../../skills/engineering-rules" && pwd)"
work="$(mktemp -d)"
[[ "${DEMO_KEEP:-0}" == "1" ]] || trap 'rm -rf "$work" "${work}".proof-*.md' EXIT
export STACK_SKIP_GATES="${STACK_SKIP_GATES:-audit}"   # keep the demo independent of the advisory database

git_c() { git -C "$work" -c user.email=demo@example.com -c user.name=Demo "$@"; }
title() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# 1. a small existing project that already adopted the rules
cp -a "${here}/base/." "$work/"
git -C "$work" init -q -b main
bash "${skill}/scripts/install.sh" --target "$work" --stack node --agents none --org acme --project shop-api --owner demo >/dev/null
cp "${here}/docs-map.yml" "$work/docs/docs-map.yml"
git_c add -A && git_c commit -q -m "chore: adopt engineering rules"
git_c update-ref refs/remotes/origin/main HEAD

# 2. the pull request many of us would open (or an AI assistant would produce)
git_c checkout -q -b feat/checkout
cp -a "${here}/before/." "$work/"
printf 'DATABASE_URL=postgres://admin:example-password@db.internal.example:5432/shop\nPAYMENT_API_KEY=example-key-not-real\n' >"$work/.env"
{ echo "// Pasted export of the product catalog."; echo "module.exports = ["
  for i in $(seq 1 1300); do printf '  { sku: "SKU-%05d", name: "Product %d", priceMinor: %d },\n' "$i" "$i" "$((100 + i))"; done
  echo "];"; } >"$work/src/catalog-data.js"
git_c add -A && git_c commit -q -m "feat: checkout"

title "BEFORE: the pull request as first written"
(cd "$work" && bash .github/scripts/local-proof.sh --title "feat: checkout" --out "${work}.proof-before.md" | sed -n '/^| Gate/,/^$/p') || true
echo "Why it failed (from the proof):"
grep -E '^::error|RuleID:|File: |Would |not ok|# fail|FAIL ' "${work}.proof-before.md" | sed -e 's/^::error file=//' -e 's/^::error:://' | cut -c1-150 | head -n 14

# 3. the same feature, done to the rules. The branch is rewritten: a secret that
#    was committed is rotated AND removed from history before the branch is shared.
title "AFTER: the same feature, rewritten to the rules"
git_c checkout -q -B feat/checkout main
cp -a "${here}/after/." "$work/"
printf -- '- Added: checkout with configurable currency, time zone and tax rate.\n' >>"$work/CHANGELOG.md"
git_c add -A && git_c commit -q -m "feat: checkout"
(cd "$work" && bash .github/scripts/local-proof.sh --title "feat: checkout" --out "${work}.proof-after.md" | sed -n '/^| Gate/,/^$/p')

if [[ "${DEMO_KEEP:-0}" == "1" ]]; then echo; echo "Repository kept at: ${work}"; fi
exit 0
