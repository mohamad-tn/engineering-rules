#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers for the stack engines. Source it; do not execute it.
#
# Every gate ends in one of five states, recorded in $STACK_RESULTS:
#   PASS    the command ran and succeeded
#   FAIL    the command ran and failed (or a policy was violated)
#   SKIP    nothing to run (no script, no config); the reason is recorded
#   NOTRUN  the gate applies but a tool or the network is missing
#   WARN    advice only; never changes the exit status
#   NA      does not apply to this stack by nature (for example PHP has no
#           build step); never counts as missing, even in strict mode
# stack-gates.sh turns SKIP and NOTRUN into a failure for the gates listed in
# STACK_REQUIRE, so "nothing ran" can never read as "all green".

STACK_CUR_ENGINE="${STACK_CUR_ENGINE:-}"
STACK_CUR_DIR="${STACK_CUR_DIR:-.}"

have() { command -v "$1" >/dev/null 2>&1; }

# in_list <needle> <comma list>
in_list() {
  local needle="$1" list="${2:-}"
  list="${list// /}"
  [[ ",${list}," == *",${needle},"* ]]
}

_record() { printf '%s\t%s\t%s\t%s\t%s\n' "$STACK_CUR_ENGINE" "$STACK_CUR_DIR" "$1" "$2" "$3" >>"$STACK_RESULTS"; }

# STACK_QUIET=1 prints only failures and gates that could not run (less noise for agents).
_say() {
  if [[ "${STACK_QUIET:-0}" == "1" && "$2" != FAIL* && "$2" != "NOT RUN"* ]]; then return 0; fi
  printf '  %-16s %s\n' "$1" "$2"
}

# A STACK_CMD_<GATE> override also rescues a gate the engine could not run or
# skipped (no script, no tool): the override is what the project chose to run.
_override_run() {
  local ov
  ov="$(_var_of "$1")"
  [[ -n "${!ov:-}" ]] || return 1
  _selected "$1" || return 0
  _run "$1" 0 bash -c "${!ov}"
}

skip() { _override_run "$1" && return 0; _record "$1" SKIP "$2"; _say "$1" "SKIP    ($2)"; }
notrun() { _override_run "$1" && return 0; _record "$1" NOTRUN "$2"; _say "$1" "NOT RUN ($2)"; }
warn() { _record "$1" WARN "$2"; _say "$1" "WARN    ($2)"; }
na() { _override_run "$1" && return 0; _record "$1" NA "$2"; _say "$1" "N/A     ($2)"; }
pass() { _record "$1" PASS "${2:-ok}"; _say "$1" "PASS${2:+    ($2)}"; }
fail() { _record "$1" FAIL "$2"; _say "$1" "FAIL    ($2)"; }

# Gate names are upper-cased with '-' as '_' for override variables.
_var_of() { local n; n="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"; printf 'STACK_CMD_%s' "${n//-/_}"; }

# _selected <name>: returns 1 (and records a SKIP) when the gate is not wanted.
_selected() {
  local name="$1"
  if [[ -n "${STACK_ONLY:-}" ]] && ! in_list "$name" "$STACK_ONLY"; then
    _record "$name" SKIP "not selected (STACK_ONLY)"
    return 1
  fi
  if in_list "$name" "${STACK_SKIP_GATES:-}"; then
    _record "$name" SKIP "disabled by STACK_SKIP_GATES"
    _say "$name" "SKIP    (disabled by STACK_SKIP_GATES)"
    return 1
  fi
  if [[ "${STACK_FAST:-0}" == "1" ]] && in_list "$name" "${STACK_FAST_SKIP:-build,audit,e2e}"; then
    _record "$name" SKIP "fast mode"
    _say "$name" "SKIP    (fast mode)"
    return 1
  fi
  return 0
}

# _with_timeout <seconds> <command...>: GNU timeout, Homebrew gtimeout, or no limit.
# (macOS has no timeout; on Windows a different timeout.exe may shadow the GNU one.)
_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1 && timeout --version 2>/dev/null | grep -q 'GNU coreutils'; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@"
  fi
}

# _run <name> <net 0|1> <command...>
_run() {
  local name="$1" net="$2"
  shift 2
  local log status=0 started=$SECONDS
  log="$(mktemp)"
  CI=1 _with_timeout "${STACK_GATE_TIMEOUT:-1800}" "$@" >"$log" 2>&1 || status=$?
  local took=$((SECONDS - started))
  if ((status == 0)); then
    pass "$name" "${took}s"
  elif [[ "$net" == "1" ]] && grep -qiE 'ENOTFOUND|EAI_AGAIN|ECONNREFUSED|Could not resolve host|Temporary failure in name resolution|Unable to load the service index|network is unreachable|getaddrinfo|dial tcp.*lookup|failed to fetch|could not connect' "$log"; then
    notrun "$name" "network unavailable"
    sed 's/^/      | /' < <(tail -n 6 "$log")
  elif ((status == 124 && took >= ${STACK_GATE_TIMEOUT:-1800} - 1)); then
    fail "$name" "timed out after ${STACK_GATE_TIMEOUT:-1800}s"
  else
    fail "$name" "exit ${status}, ${took}s"
    sed 's/^/      | /' < <(tail -n "${STACK_LOG_LINES:-25}" "$log")
  fi
  rm -f "$log"
}

# gate <name> -- <command...>      run an external command as a gate
gate() {
  local name="$1"
  shift
  [[ "${1:-}" == "--" ]] && shift
  _selected "$name" || return 0
  local override
  override="$(_var_of "$name")"
  if [[ -n "${!override:-}" ]]; then
    _run "$name" 0 bash -c "${!override}"
  else
    _run "$name" 0 "$@"
  fi
}

# gate_net <name> -- <command...>  same, but a network failure is NOT RUN, not FAIL
gate_net() {
  local name="$1"
  shift
  [[ "${1:-}" == "--" ]] && shift
  _selected "$name" || return 0
  local override
  override="$(_var_of "$name")"
  if [[ -n "${!override:-}" ]]; then
    _run "$name" 1 bash -c "${!override}"
  else
    _run "$name" 1 "$@"
  fi
}

# gate_sh <name> '<shell string>' [net]   run a compound shell command
gate_sh() {
  local name="$1" cmd="$2" net="${3:-0}"
  _selected "$name" || return 0
  local override
  override="$(_var_of "$name")"
  [[ -n "${!override:-}" ]] && cmd="${!override}"
  _run "$name" "$net" bash -c "set -euo pipefail; ${cmd}"
}

# find_up <file> [start dir]: prints the directory (at or above start, up to the
# git root) that contains <file>.
find_up() {
  local file="$1" dir top
  dir="$(cd "${2:-.}" && pwd)"
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")"
  while :; do
    [[ -e "${dir}/${file}" ]] && { printf '%s\n' "$dir"; return 0; }
    [[ "$dir" == "$top" || "$dir" == "/" ]] && return 1
    dir="$(dirname "$dir")"
  done
}

# any_file <glob...>: true when at least one glob matches an existing path.
any_file() {
  local g
  for g in "$@"; do
    compgen -G "$g" >/dev/null && return 0
  done
  return 1
}

# file_has <regex> <files...>: true when any readable file matches.
file_has() {
  local re="$1"
  shift
  local f
  for f in "$@"; do
    [[ -f "$f" ]] && grep -qE "$re" "$f" && return 0
  done
  return 1
}

# Directory that holds the bundled helper tools (secret-file check, bundle scan).
STACK_TOOLS_DIR="${STACK_TOOLS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tools}"
