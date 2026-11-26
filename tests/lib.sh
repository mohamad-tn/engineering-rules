#!/usr/bin/env bash
# shellcheck shell=bash
# Tiny test helpers shared by the test files.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${REPO_ROOT}/skills/engineering-rules"
FIXTURES="${REPO_ROOT}/tests/fixtures"
STUBS="${REPO_ROOT}/tests/stubs"
export STUBS
PASSED=0
FAILED=0
SKIPPED=0
# Locally installed test tools (hadolint, tofu...) live here when present.
[[ -n "${TOOLS_DIR:-}" && -d "${TOOLS_DIR}/bin" ]] && export PATH="${TOOLS_DIR}/bin:${PATH}"
export DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 COMPOSER_ALLOW_SUPERUSER=1 NEXT_TELEMETRY_DISABLED=1

ok() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
bad() { echo "  FAIL  $1" >&2; FAILED=$((FAILED + 1)); }
skipped() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED + 1)); }

# git_init <dir>: commits everything in <dir>.
git_init() {
  git -C "$1" init -q -b main
  git -C "$1" add -A
  git -C "$1" -c user.email=t@example.com -c user.name=Test commit -q -m init
}

# fixture_copy <fixture path>: copies a fixture into a fresh git repository; prints the path.
fixture_copy() {
  local t
  t="$(mktemp -d)"
  cp -a "${FIXTURES}/$1/." "$t/"
  git_init "$t"
  printf '%s\n' "$t"
}

# run_stack <dir> [env VAR=value ...]: runs stack-gates.sh; output in $OUT, status in $RC.
run_stack() {
  local dir="$1"
  shift
  OUT="$(env "$@" bash "${SKILL}/scripts/stack-gates.sh" --root "$dir" 2>&1)"
  RC=$?
}

# check_fixture <name> <fixture> <expect: pass|fail> <pattern> [env ...]
check_fixture() {
  local name="$1" fx="$2" expect="$3" pattern="$4"
  shift 4
  local dir
  dir="$(fixture_copy "$fx")"
  run_stack "$dir" "$@"
  local want=0
  [[ "$expect" == "fail" ]] && want=1
  if [[ "$RC" != "$want" ]]; then
    bad "${name}: expected exit ${want}, got ${RC}"
    printf '%s\n' "$OUT" | tail -n 25 | sed 's/^/        /' >&2
  elif [[ -n "$pattern" ]] && ! grep -qE -- "$pattern" <<<"$OUT"; then
    bad "${name}: output does not match /${pattern}/"
    printf '%s\n' "$OUT" | tail -n 25 | sed 's/^/        /' >&2
  else
    ok "$name"
  fi
  rm -rf "$dir"
}

summary() {
  echo
  echo "passed: ${PASSED}  failed: ${FAILED}  skipped: ${SKIPPED}"
  [[ "$FAILED" -eq 0 ]]
}
