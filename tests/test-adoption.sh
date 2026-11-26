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

echo "== legacy repository: changed docs pass without linting untouched legacy Markdown"
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
cat >"$repo/CHANGELOG.md" <<'CHANGELOG'
# Changelog

## Unreleased

- Added: sub.
CHANGELOG
cat >"$repo/docs/README.md" <<'DOCS'
# Documentation

More.
DOCS
commit "$repo" "feat: add sub"
base="$(git -C "$repo" rev-parse origin/master)"; head="$(git -C "$repo" rev-parse HEAD)"
(cd "$repo" && BASE_SHA="$base" HEAD_SHA="$head" PR_TITLE="feat: add sub" PR_LABELS_JSON="[]" bash .github/scripts/docs-check.sh . >/tmp/dc-changed.out 2>&1); rc=$?
if [[ "$rc" == 0 ]]; then
  ok "changed docs pass while malformed legacy Markdown remains untouched"
elif grep -qiE 'lychee is not available|pinned downloads support|could not be downloaded|no network' /tmp/dc-changed.out; then
  skipped "changed-docs integration (lychee is unavailable in this environment)"
else
  bad "changed docs check rc=$rc"; cat /tmp/dc-changed.out >&2
fi
(cd "$repo" && DOCS_LINT_SCOPE=all BASE_SHA="$base" HEAD_SHA="$head" PR_TITLE="feat: add sub" PR_LABELS_JSON="[]" bash .github/scripts/docs-check.sh . >/tmp/dc-all.out 2>&1); rc=$?
if [[ "$rc" != 0 ]] && grep -q "LEGACY.md" /tmp/dc-all.out; then ok "DOCS_LINT_SCOPE=all does lint the old files"; else bad "scope all rc=$rc"; tail -n 8 /tmp/dc-all.out >&2; fi
if command -v go >/dev/null 2>&1; then
  out="$(cd "$repo" && STACK_SKIP_GATES=audit bash .github/scripts/local-proof.sh --title "feat: add sub" 2>&1)"; rc=$?
  if [[ "$rc" == 0 ]] && grep -q "| docs-check .*PASS" <<<"$out"; then ok "local-proof detects the master default branch"; else bad "legacy local-proof rc=$rc"; printf '%s\n' "$out" | tail -n 25 >&2; fi
else
  skipped "local-proof branch-detection integration (Go fixture needs go)"
fi

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
scan_out="$(cd "$sec" && bash .github/scripts/gitleaks-scan.sh .gitleaks.toml 2>&1)"; scan_rc=$?
if [[ "$scan_rc" == 1 ]] && grep -qE '(^|[[:space:]])\.env([[:space:]]|$)' <<<"$scan_out"; then
  ok "the full-history scan still catches the old .env"
  scan_from_out="$(cd "$sec" && SECRET_SCAN_FROM="$adopt" bash .github/scripts/gitleaks-scan.sh .gitleaks.toml 2>&1)"; scan_from_rc=$?
  if [[ "$scan_from_rc" == 0 ]] && grep -q "SECRET_SCAN_FROM" <<<"$scan_from_out"; then ok "SECRET_SCAN_FROM scans only newer commits and says so loudly"; else bad "scan-from rc=$scan_from_rc"; tail -n 5 <<<"$scan_from_out" >&2; fi
elif grep -qiE 'pinned downloads support|not on PATH and no pin is set|could not resolve|failed to connect|exec format error|no network' <<<"$scan_out"; then
  skipped "history scan (gitleaks is unavailable or could not be downloaded on this environment)"
  skipped "SECRET_SCAN_FROM integration (gitleaks is unavailable or could not be downloaded on this environment)"
else
  bad "full-history scan did not report the expected .env finding (rc=$scan_rc)"; tail -n 10 <<<"$scan_out" >&2
fi

echo "== machine-readable output for agents"
dir="$(fixture_copy node/bad)"
json="$(STACK_ONLY=test STACK_CMD_TEST=false STACK_REQUIRE=test bash "${SKILL}/scripts/stack-gates.sh" --root "$dir" --json 2>/dev/null)"
if node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.exit(j.ok===false && j.failed.length>0 && j.projects[0].engine==="node" ? 0 : 1)' <<<"$json"; then ok "stack-gates --json is valid JSON with the failing gates"; else bad "stack-gates --json"; echo "$json" | head -n 12 >&2; fi
quiet="$(STACK_ONLY=test STACK_CMD_TEST=false STACK_REQUIRE=test bash "${SKILL}/scripts/stack-gates.sh" --root "$dir" --quiet 2>&1)"
if ! grep -qE "^  deps +PASS" <<<"$quiet" && grep -qE "FAIL" <<<"$quiet"; then ok "--quiet hides passing gates and keeps the failures"; else bad "--quiet"; fi
pj="$(cd "$repo" && STACK_SKIP_GATES=audit bash .github/scripts/local-proof.sh --title "feat: add sub" --json 2>/dev/null)"
if node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.exit(typeof j.ok==="boolean" && j.gates.some(g=>g.gate==="Stack gates") ? 0 : 1)' <<<"$pj"; then ok "local-proof --json is valid JSON"; else bad "local-proof --json"; echo "$pj" | head -n 8 >&2; fi
summary
