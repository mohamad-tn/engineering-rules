#!/usr/bin/env bash
# Self-test for the gate scripts in this package. Builds a throw-away git
# repository and checks that each gate passes on good input and fails on bad
# input. Run it after you change a gate:   bash scripts/selftest.sh
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
templates="${here}/../templates"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0

ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1" >&2; exit 1; }
expect_status() { # <expected> <name> <command...>
  local expected="$1" name="$2" status=0
  shift 2
  "$@" >"${tmp}/out.log" 2>&1 || status=$?
  if [[ "$status" == "$expected" ]]; then
    ok "$name"
  else
    cat "${tmp}/out.log" >&2
    bad "$name (expected ${expected}, got ${status})"
  fi
}
expect_output() { # <name> <pattern...>: the last command's output must match every pattern
  local name="$1" pattern
  shift
  for pattern in "$@"; do
    grep -q -- "$pattern" "${tmp}/out.log" || { cat "${tmp}/out.log" >&2; bad "${name} (missing: ${pattern})"; }
  done
  ok "$name"
}
# Gates that use git run in the repository's working directory.
inrepo() { (cd "$repo" && "$@"); }

repo="${tmp}/repo"
mkdir -p "$repo/docs" "$repo/src" "$repo/.github/docs-check"
git -C "$repo" init -q -b main
git_commit() { git -C "$repo" add -A && git -C "$repo" -c user.email=t@example.com -c user.name=T commit -q -m "$1"; }

printf '# Readme\n' >"$repo/README.md"
printf '# Changelog\n\n## Unreleased\n' >"$repo/CHANGELOG.md"
printf '# Docs\n' >"$repo/docs/README.md"
cat >"$repo/docs/docs-map.yml" <<'MAP'
# code -> docs
- code: "src/**"
  docs: ["docs/**", "CHANGELOG.md"]
MAP
cat >"$repo/.github/docs-check/required-docs.json" <<'REQ'
{ "*": ["README.md", "CHANGELOG.md", "docs/docs-map.yml"] }
REQ
git_commit base
base="$(git -C "$repo" rev-parse HEAD)"

# --- docs-check structure -------------------------------------------------
expect_status 0 "docs-check: whole-repo rules pass" node "${templates}/docs-check.mjs" "$repo"
echo 'export const a = 1;' >"$repo/src/a.ts"
git_commit "feat: add a"
head="$(git -C "$repo" rev-parse HEAD)"
expect_status 1 "docs-check: code change without docs fails" \
  env BASE_SHA="$base" HEAD_SHA="$head" PR_TITLE="feat: add a" PR_LABELS_JSON='[]' node "${templates}/docs-check.mjs" "$repo"
expect_status 0 "docs-check: skip label accepted" \
  env BASE_SHA="$base" HEAD_SHA="$head" PR_TITLE="feat: add a" PR_LABELS_JSON='["no-docs-needed"]' node "${templates}/docs-check.mjs" "$repo"
echo 'note' >>"$repo/docs/README.md"
printf -- '- feat: add a\n' >>"$repo/CHANGELOG.md"
git_commit "feat: add a with docs"
head2="$(git -C "$repo" rev-parse HEAD)"
expect_status 0 "docs-check: code + docs + changelog passes" \
  env BASE_SHA="$base" HEAD_SHA="$head2" PR_TITLE="feat: add a" PR_LABELS_JSON='[]' node "${templates}/docs-check.mjs" "$repo"
printf 'bad line\n' >"$repo/docs/docs-map.yml"
expect_status 1 "docs-check: malformed map fails" node "${templates}/docs-check.mjs" "$repo"
git -C "$repo" checkout -q -- docs/docs-map.yml

# --- PR size --------------------------------------------------------------
mkdir -p "$repo/src/__snapshots__"
seq 1 450 >"$repo/src/big.ts"
seq 1 900 >"$repo/src/__snapshots__/x.snap"
git_commit "feat: big"
head3="$(git -C "$repo" rev-parse HEAD)"
expect_status 0 "pr-size: snapshots excluded, 450 lines only warns" \
  inrepo env BASE_SHA="$head2" HEAD_SHA="$head3" bash "${templates}/pr-size-check.sh"
expect_output "pr-size: warning printed and 450 counted" "::warning::" "450 counted lines"
expect_status 1 "pr-size: above fail threshold fails" \
  inrepo env BASE_SHA="$head2" HEAD_SHA="$head3" FAIL_LINES=440 bash "${templates}/pr-size-check.sh"
expect_status 0 "pr-size: reason label lets it pass" \
  inrepo env BASE_SHA="$head2" HEAD_SHA="$head3" FAIL_LINES=440 PR_LABELS_JSON='["pr-size-reason"]' bash "${templates}/pr-size-check.sh"
git -C "$repo" mv src/big.ts src/renamed.ts
git_commit "chore: rename"
head4="$(git -C "$repo" rev-parse HEAD)"
expect_status 0 "pr-size: pure rename counts nothing" \
  inrepo env BASE_SHA="$head3" HEAD_SHA="$head4" bash "${templates}/pr-size-check.sh"
expect_output "pr-size: rename counted as 0" "PR size: 0 counted lines"

# --- policy gates ---------------------------------------------------------
expect_status 0 "policy-gates: clean repo passes" node "${here}/policy-gates.mjs" "$repo"
printf 'export const currency = "USD";\n' >"$repo/src/price.ts"
printf '{"name":"x","dependencies":{"left-pad":"2.0.0-beta.1"}}\n' >"$repo/package.json"
git_commit "feat: literals"
expect_status 1 "policy-gates: currency literal and prerelease fail" node "${here}/policy-gates.mjs" "$repo"
expect_output "policy-gates: both findings reported" "currency code" "prerelease"
mkdir -p "$repo/.github/policy"
echo '[{"name":"left-pad","version":"2.0.0-beta.1","adr":"docs/adr/0001.md"}]' >"$repo/.github/policy/prerelease-allow.json"
rm "$repo/src/price.ts"
git_commit "chore: allow"
expect_status 0 "policy-gates: allowlisted prerelease passes" node "${here}/policy-gates.mjs" "$repo"

# --- feature-flag expiry --------------------------------------------------
expect_status 0 "flag-expiry: no registry passes" node "${here}/feature-flag-expiry.mjs" "$repo"
echo '{"flags":[{"id":"f1","owner":"team","purpose":"test","expiresOn":"2000-01-01"}]}' >"$repo/feature-flags.json"
expect_status 1 "flag-expiry: expired flag fails" node "${here}/feature-flag-expiry.mjs" "$repo"
echo '{"flags":[{"id":"f1","owner":"team","purpose":"test","expiresOn":"2999-01-01"}]}' >"$repo/feature-flags.json"
expect_status 0 "flag-expiry: future flag passes" node "${here}/feature-flag-expiry.mjs" "$repo"
echo '{"flags":[{"id":"f1","owner":"team","purpose":"test","expiresOn":"2099-02-31"}]}' >"$repo/feature-flags.json"
expect_status 1 "flag-expiry: impossible calendar date fails" node "${here}/feature-flag-expiry.mjs" "$repo"

# --- sha256 lock ----------------------------------------------------------
echo "data" >"${tmp}/data.json"
if command -v sha256sum >/dev/null 2>&1; then sha256sum "${tmp}/data.json"; else shasum -a 256 "${tmp}/data.json"; fi >"${tmp}/data.json.sha256"
cat >"${tmp}/lock.mjs" <<'LOCK'
import { pathToFileURL } from "node:url";
const { assertSha256Lock } = await import(pathToFileURL(process.argv[2]).href);
assertSha256Lock(process.argv[3], process.argv[4], "update the lock");
LOCK
expect_status 0 "sha256-lock: matching digest passes" node "${tmp}/lock.mjs" "${here}/assert-sha256-lock.mjs" "${tmp}/data.json" "${tmp}/data.json.sha256"
echo "changed" >>"${tmp}/data.json"
expect_status 1 "sha256-lock: changed file fails" node "${tmp}/lock.mjs" "${here}/assert-sha256-lock.mjs" "${tmp}/data.json" "${tmp}/data.json.sha256"

# --- ci-local event (offline payload) -------------------------------------
git -C "$repo" remote add origin "https://example.com/org/project.git" 2>/dev/null || git -C "$repo" remote add origin "https://example.com/org/project.git"
git -C "$repo" update-ref refs/remotes/origin/main "$base"
if command -v jq >/dev/null 2>&1; then
  expect_status 0 "ci-local: offline event payload builds" bash "${here}/ci-local.sh" event "$repo" --label dependencies
fi

echo
echo "selftest: ${pass} checks passed"
