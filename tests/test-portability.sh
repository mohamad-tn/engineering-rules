#!/usr/bin/env bash
# Portability: the scripts must work on macOS (bash 3.2 default, BSD sed, no GNU
# timeout) and on Git Bash for Windows (a different timeout.exe on PATH). We cannot run
# those systems here, so we simulate their differences with shims.
# shellcheck disable=SC2015
set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
export TOOLS_DIR="${TOOLS_DIR:-${HOME}/.cache/engineering-rules-skill/tools}"

echo "== portability (simulated)"
shim="$(mktemp -d)"

# 1. A foreign `timeout` (Windows timeout.exe, or none): gates must still run.
cat >"$shim/timeout" <<'SH'
#!/bin/sh
echo "ERROR: Invalid syntax (this is not GNU timeout)" >&2
exit 1
SH
chmod +x "$shim/timeout"
if command -v go >/dev/null 2>&1; then
  dir="$(fixture_copy go/good)"
  run_stack "$dir" PATH="$shim:$PATH"
  if [[ "$RC" == 0 ]] && grep -qE "test +PASS" <<<"$OUT"; then ok "a foreign timeout on PATH does not break the gates"; else bad "foreign timeout rc=$RC"; printf '%s\n' "$OUT" | tail -n 8 >&2; fi
  rm -rf "$dir"
else
  skipped "foreign timeout (needs go)"
fi

# 2. BSD sed rejects a bare -i: nothing may use it.
rm -f "$shim/timeout"
cat >"$shim/sed" <<'SH'
#!/bin/sh
for a in "$@"; do
  if [ "$a" = "-i" ]; then echo "sed: BSD sed needs a backup suffix after -i" >&2; exit 1; fi
done
exec /usr/bin/sed "$@"
SH
chmod +x "$shim/sed"
[ -x /usr/bin/sed ] || sed -i.bak 's#/usr/bin/sed#/bin/sed#' "$shim/sed"
target="$(mktemp -d)"
echo "# demo" >"$target/README.md"
git_init "$target"
out="$(PATH="$shim:$PATH" bash "${SKILL}/scripts/install.sh" --target "$target" --stack none --org acme --project shop --owner jane 2>&1)"; rc=$?
if [[ "$rc" == 0 ]] && grep -q "@jane" "$target/.github/CODEOWNERS"; then ok "installer works with BSD-style sed (no bare -i)"; else bad "BSD sed shim rc=$rc"; echo "$out" | tail -n 5 >&2; fi
rm -rf "$target"
# Use a tiny unpublished tree so this still runs after placeholders are filled.
prep="$(mktemp -d)"
mkdir -p "$prep/tools"
cp "$REPO_ROOT/tools/publish-prep.sh" "$prep/tools/"
printf 'MIT License\n\nCopyright (c) __YEAR__ __AUTHOR__\n' >"$prep/LICENSE"
printf 'https://github.com/__GH_OWNER__/__GH_REPO__\n' >"$prep/README.md"
if PATH="$shim:$PATH" bash "$prep/tools/publish-prep.sh" --owner octo --author "Octo" >/dev/null 2>&1 && grep -q 'Copyright (c) .* Octo' "$prep/LICENSE"; then ok "publish-prep works with BSD-style sed"; else bad "publish-prep with BSD sed"; fi
rm -rf "$prep"

# 3. Old bash: a clear message (or a re-exec into a newer bash), never a cryptic crash.
for s in install.sh stack-gates.sh local-proof.sh doctor.sh; do
  out="$(ER_BASH_MAJOR=3 PATH="/usr/bin:/bin" /usr/bin/env bash "${SKILL}/scripts/${s}" --help 2>&1)"; rc=$?
  if [[ "$rc" == 2 ]] && grep -q "needs bash 4 or newer" <<<"$out"; then ok "${s}: bash 3.2 gets a clear upgrade message"; else
    # a Homebrew bash on this machine would legitimately take over
    if [[ -x /opt/homebrew/bin/bash || -x /usr/local/bin/bash ]]; then skipped "${s}: bash guard (a newer bash is installed here)"; else bad "${s}: bash guard rc=$rc"; fi
  fi
done

# 4. Paths with spaces.
spaced="$(mktemp -d)/my project"
mkdir -p "$spaced"
cp -a "${FIXTURES}/go/good/." "$spaced/"
git_init "$spaced"
if command -v go >/dev/null 2>&1; then
  run_stack "$spaced"
  if [[ "$RC" == 0 ]]; then ok "a repository path with spaces works"; else bad "spaces in path rc=$RC"; printf '%s\n' "$OUT" | tail -n 6 >&2; fi
fi
out="$(bash "${SKILL}/scripts/install.sh" --target "$spaced" --stack none 2>&1)"; rc=$?
[[ "$rc" == 0 ]] && ok "installer handles a path with spaces" || { bad "installer with spaces rc=$rc"; echo "$out" | tail -n 4 >&2; }
rm -rf "$shim" "$(dirname "$spaced")"
summary
