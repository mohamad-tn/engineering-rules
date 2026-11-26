#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Real-world adoption: legacy repositories (messy docs, old secrets in history, a
# `master` default branch) and machine-readable output for agents.
set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
export TOOLS_DIR="${TOOLS_DIR:-${HOME}/.cache/engineering-rules-skill/tools}"
INSTALL="${SKILL}/scripts/install.sh"
commit() { git -C "$1" add -A && git -C "$1" -c user.email=t@example.com -c user.name=T commit -q -m "$2"; }

echo "== legacy repository: messy docs do not block adoption"
repo="$(mktemp -d)"
printf '# Old docs\n\n### skipped a heading level\n\n```\nno language on this fence\n```\n' >"$repo/LEGACY.md"
printf '# Project\n' >"$repo/README.md"
cp -a "${FIXTURES}/go/good/." "$repo/"
git -C "$repo" init -q -b master
commit "$repo" "legacy state"
bash "$INSTALL" --target "$repo" --stack go --profile standard --org acme --project shop >/dev/null 2>&1
git -C "$repo" update-ref refs/remotes/origin/master HEAD
commit "$repo" "chore: adopt engineering rules"
git -C "$repo" update-ref refs/remotes/origin/master HEAD
git -C "$repo" checkout -q -b feat/x
printf 'package main\n\n// Doc.\nfunc Sub(a, b int) int { return a - b }\n' >"$repo/sub.go"
printf -- '- Added: sub.\n' >>"$repo/CHANGELOG.md"
printf "\nMore.\n" >>"$repo/docs/README.md"
commit "$repo" "feat: add sub"
out="$(cd "$repo" && STACK_SKIP_GATES=audit bash .github/scripts/local-proof.sh --title "feat: add sub" 2>&1)"; rc=$?
if [[ "$rc" == 0 ]] && grep -q "| docs-check .*PASS" <<<"$out"; then ok "default branch is detected (master) and old markdown is not linted"; else bad "legacy repo local-proof rc=$rc"; printf '%s\n' "$out" | head -n 25 >&2; fi
base="$(git -C "$repo" rev-parse origin/master)"; head="$(git -C "$repo" rev-parse HEAD)"
(cd "$repo" && DOCS_LINT_SCOPE=all BASE_SHA="$base" HEAD_SHA="$head" PR_TITLE="feat: add sub" PR_LABELS_JSON="[]" bash .github/scripts/docs-check.sh . >/tmp/dc-all.out 2>&1); rc=$?
if [[ "$rc" != 0 ]] && grep -q "LEGACY.md" /tmp/dc-all.out; then ok "DOCS_LINT_SCOPE=all does lint the old files"; else bad "scope all rc=$rc"; tail -n 8 /tmp/dc-all.out >&2; fi

echo "== legacy history: old secrets can be handled explicitly, never silently"
sec="$(mktemp -d)"
printf '# demo\n' >"$sec/README.md"
printf 'API=x\n' >"$sec/.env"
git -C "$sec" init -q -b main
commit "$sec" "oops: committed a .env"
git -C "$sec" rm -q --cached .env && rm "$sec/.env" && commit "$sec" "remove .env"
bash "$INSTALL" --target "$sec" --stack none >/dev/null 2>&1
commit "$sec" "chore: adopt engineering rules"
adopt="$(git -C "$sec" rev-parse HEAD)"
(cd "$sec" && bash .github/scripts/gitleaks-scan.sh .gitleaks.toml >/tmp/gl-full.out 2>&1); rc=$?
if [[ "$rc" == 1 ]]; then ok "the full-history scan still catches the old .env"; elif grep -q "gitleaks" /tmp/gl-full.out && [[ "$rc" != 0 ]]; then skipped "history scan (gitleaks could not be installed)"; else bad "full scan rc=$rc"; fi
(cd "$sec" && SECRET_SCAN_FROM="$adopt" bash .github/scripts/gitleaks-scan.sh .gitleaks.toml >/tmp/gl-from.out 2>&1); rc=$?
if [[ "$rc" == 0 ]] && grep -q "SECRET_SCAN_FROM" /tmp/gl-from.out; then ok "SECRET_SCAN_FROM scans only newer commits and says so loudly"; else bad "scan-from rc=$rc"; tail -n 5 /tmp/gl-from.out >&2; fi

echo "== machine-readable output for agents"
dir="$(fixture_copy go/bad)"
json="$(bash "${SKILL}/scripts/stack-gates.sh" --root "$dir" --json 2>/dev/null)"
if node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.exit(j.ok===false && j.failed.some(f=>f.gate==="format") && j.projects[0].engine==="go" ? 0 : 1)' <<<"$json"; then ok "stack-gates --json is valid JSON with the failing gates"; else bad "stack-gates --json"; echo "$json" | head -n 12 >&2; fi
quiet="$(bash "${SKILL}/scripts/stack-gates.sh" --root "$dir" --quiet 2>&1)"
if ! grep -qE "^  deps +PASS" <<<"$quiet" && grep -qE "FAIL" <<<"$quiet"; then ok "--quiet hides passing gates and keeps the failures"; else bad "--quiet"; fi
pj="$(cd "$repo" && STACK_SKIP_GATES=audit bash .github/scripts/local-proof.sh --title "feat: add sub" --json 2>/dev/null)"
if node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.exit(typeof j.ok==="boolean" && j.gates.some(g=>g.gate==="Stack gates") ? 0 : 1)' <<<"$pj"; then ok "local-proof --json is valid JSON"; else bad "local-proof --json"; echo "$pj" | head -n 8 >&2; fi
summary
