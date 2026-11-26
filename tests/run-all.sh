#!/usr/bin/env bash
# Runs every test file. Usage: bash tests/run-all.sh [static|stacks|installer|demo|core|parity|portability|adoption|context]
set -uo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
want="${1:-all}"
case "$want" in all|static|stacks|installer|demo|core|parity|portability|adoption|context) ;; *)
  echo "unknown test suite: ${want}" >&2
  echo "usage: bash tests/run-all.sh [static|stacks|installer|demo|core|parity|portability|adoption|context]" >&2
  exit 2
  ;;
esac
failed=0
run() {
  local name="$1"
  shift
  [[ "$want" == "all" || "$want" == "$name" ]] || return 0
  echo
  echo "################ ${name}"
  "$@" || failed=1
}
run core bash "${repo}/skills/engineering-rules/scripts/selftest.sh"
run stacks bash "${here}/test-stacks.sh"
run installer bash "${here}/test-installer.sh"
run portability bash "${here}/test-portability.sh"
run adoption bash "${here}/test-adoption.sh"
run demo bash "${here}/test-demo.sh"
run parity bash "${here}/test-parity.sh"
run context bash "${here}/test-context.sh"
run static bash "${here}/test-static.sh"
echo
if ((failed)); then echo "TESTS FAILED"; exit 1; fi
echo "ALL TESTS PASSED"
