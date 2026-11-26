#!/usr/bin/env bash
# Installer, doctor and local-proof tests: adopt the rules in throw-away
# repositories and check the result end to end.
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
INSTALL="${SKILL}/scripts/install.sh"
export TOOLS_DIR="${TOOLS_DIR:-${HOME}/.cache/engineering-rules-skill/tools}"

new_repo() { # <fixture or empty>
  local t
  t="$(mktemp -d)"
  if [[ -n "${1:-}" ]]; then cp -a "${FIXTURES}/$1/." "$t/"; else echo "# demo" >"$t/README.md"; fi
  git_init "$t"
  printf '%s\n' "$t"
}

echo "== installer"
repo="$(new_repo go/good)"
out="$(bash "$INSTALL" --target "$repo" --org acme --project shop --owner jane 2>&1)"; rc=$?
[[ "$rc" == 0 ]] && ok "install into a Go repository" || { bad "install rc=$rc"; echo "$out" >&2; }
for f in AGENTS.md CLAUDE.md .cursor/rules/engineering-rules.mdc .github/copilot-instructions.md GEMINI.md \
  .github/workflows/project-gates.yml .github/workflows/stack-go.yml .github/CODEOWNERS .gitleaks.toml \
  .github/engineering-rules.env .github/scripts/stack-gates.sh .github/scripts/stacks/go.sh docs/docs-map.yml; do
  [[ -e "$repo/$f" ]] && ok "installed ${f}" || bad "missing ${f}"
done
[[ ! -e "$repo/.github/workflows/stack-node.yml" ]] && ok "only the detected stack workflow is installed" || bad "unexpected node workflow"
grep -q "@jane" "$repo/.github/CODEOWNERS" && ! grep -rq '<owner>' "$repo/.github/CODEOWNERS" && ok "placeholders filled (<owner>)" || bad "owner placeholder"
grep -q 'local>acme/shop//renovate/default' "$repo/renovate.json" && ok "placeholders filled (<org>, <project>)" || bad "org/project placeholder"
[[ -x "$repo/.github/scripts/local-proof.sh" ]] && ok "scripts are executable" || bad "scripts not executable"

# idempotent: a second run keeps edited files
echo "# my own rules" >"$repo/AGENTS.md"
out="$(bash "$INSTALL" --target "$repo" 2>&1)"
grep -q "# my own rules" "$repo/AGENTS.md" && ok "second run never overwrites existing files" || bad "overwrote AGENTS.md"
grep -q "kept (already existed)" <<<"$out" && ok "report lists kept files" || bad "no kept report"
bash "$INSTALL" --target "$repo" --force >/dev/null 2>&1
grep -q "# my own rules" "$repo/AGENTS.md" && bad "--force did not overwrite" || ok "--force overwrites"

# dry run
dry="$(new_repo '')"
bash "$INSTALL" --target "$dry" --dry-run >/dev/null 2>&1
[[ ! -e "$dry/AGENTS.md" && ! -d "$dry/.github" ]] && ok "--dry-run changes nothing" || bad "dry run wrote files"

# options
multi="$(new_repo '')"
bash "$INSTALL" --target "$multi" --layout member --stack none --agents claude,cursor --profile strict >/dev/null 2>&1
grep -q '<org>/infra/.github/actions/secret-scan' "$multi/.github/workflows/project-gates.yml" && ok "--layout member installs the shared-gates workflow" || bad "member layout"
[[ -e "$multi/CLAUDE.md" && ! -e "$multi/GEMINI.md" ]] && ok "--agents limits the bridge files" || bad "agents option"
grep -q "STACK_STRICT=1" "$multi/.github/engineering-rules.env" && ok "--profile strict is applied" || bad "profile"
bash "$INSTALL" --target "$multi" --stack nonsense >/dev/null 2>&1 && bad "unknown stack accepted" || ok "unknown stack is rejected"
nx="$(new_repo nextjs/good)"
bash "$INSTALL" --target "$nx" --stack-configs >/dev/null 2>&1
[[ -e "$nx/.github/workflows/stack-nextjs.yml" && -e "$nx/public-surface.yml" ]] && ok "next.js is detected; --stack-configs copies recommended configs" || bad "nextjs detection"
fl="$(new_repo flutter/good)"
bash "$INSTALL" --target "$fl" >/dev/null 2>&1
grep -q "STACK_REQUIRE=deps,test" "$fl/.github/engineering-rules.env" && ok "flutter gets its own required-gate default" || bad "flutter defaults"

# A symlinked parent must never redirect writes outside the chosen target.
unsafe="$(new_repo '')"; outside="$(mktemp -d)"
mkdir -p "$unsafe/.github"; ln -s "$outside" "$unsafe/.github/scripts"
out="$(bash "$INSTALL" --target "$unsafe" --stack none 2>&1)"; rc=$?
if [[ "$rc" != 0 ]] && grep -q "refusing symlink in destination path" <<<"$out" && [[ -z "$(find "$outside" -mindepth 1 -print -quit)" ]]; then
  ok "installer refuses symlinked destination parents without writing outside target"
else
  bad "installer followed symlink (rc=$rc)"; printf '%s\n' "$out" >&2
fi
rm -rf "$unsafe" "$outside"

echo "== update (managed files refresh, your edits survive)"
upd="$(new_repo go/good)"
bash "$INSTALL" --target "$upd" --stack go --org acme --project shop --owner jane >/dev/null 2>&1
[[ -f "$upd/.github/engineering-rules.manifest" ]] && grep -q ".github/scripts/stack-gates.sh" "$upd/.github/engineering-rules.manifest" && ok "install records a manifest of the files it owns" || bad "manifest"
newskill="$(mktemp -d)"
cp -a "${SKILL}/." "$newskill/"
echo "# v2 change" >>"$newskill/scripts/policy-gates.mjs"
echo "# v2 change" >>"$newskill/scripts/stacks/go.sh"
echo "# my own tweak" >>"$upd/.github/scripts/stacks/go.sh"
echo "# my own rules" >>"$upd/AGENTS.md"
out="$(bash "$newskill/scripts/install.sh" --target "$upd" --update 2>&1)"; rc=$?
[[ "$rc" == 0 ]] && grep -q "v2 change" "$upd/.github/scripts/policy-gates.mjs" && ok "update refreshes a script you did not touch" || { bad "update refresh rc=$rc"; echo "$out" | tail -n 8 >&2; }
grep -q "my own tweak" "$upd/.github/scripts/stacks/go.sh" && [[ -f "$upd/.github/scripts/stacks/go.sh.new" ]] && grep -q "CONFLICT" <<<"$out" && ok "update keeps a file you edited and writes the new version as .new" || bad "update conflict handling"
grep -q "my own rules" "$upd/AGENTS.md" && ok "update never touches AGENTS.md, docs or configs" || bad "update touched AGENTS.md"
grep -q "conflicts 1" <<<"$out" && ok "update reports a summary" || bad "update summary"
bash "$INSTALL" --target "$dry" --update >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "update without a manifest is refused with a clear message" || bad "update without manifest"
rm -rf "$newskill"

upd_unsafe="$(new_repo go/good)"; update_outside="$(mktemp -d)"
bash "$INSTALL" --target "$upd_unsafe" --stack go >/dev/null 2>&1
rm -rf "$upd_unsafe/.github/scripts"; ln -s "$update_outside" "$upd_unsafe/.github/scripts"
out="$(bash "$INSTALL" --target "$upd_unsafe" --update 2>&1)"; rc=$?
if [[ "$rc" != 0 ]] && grep -q "refusing symlink in destination path" <<<"$out" && [[ -z "$(find "$update_outside" -mindepth 1 -print -quit)" ]]; then
  ok "installer update refuses symlinked managed paths"
else
  bad "installer update followed symlink (rc=$rc)"; printf '%s\n' "$out" >&2
fi
rm -rf "$upd_unsafe" "$update_outside"

# ci-local: parse canonical SSH remote slugs and refuse uncommitted source/workflows before act.
ci_repo="$(new_repo '')"
git -C "$ci_repo" remote add origin ssh://git@github.com/acme/shop.git
git -C "$ci_repo" update-ref refs/remotes/origin/main HEAD
git -C "$ci_repo" checkout -q -b feature/ci-local
slug_json="$(bash "${SKILL}/scripts/ci-local.sh" event "$ci_repo")"
[[ "$(jq -r .repository.full_name <<<"$slug_json")" == "acme/shop" ]] && ok "ci-local parses ssh:// remotes into owner/repository" || bad "ci-local SSH slug"
echo "untracked" >"$ci_repo/untracked-source.txt"
out="$(bash "${SKILL}/scripts/ci-local.sh" run "$ci_repo" 2>&1)"; rc=$?
[[ "$rc" != 0 ]] && grep -q "tracked or untracked changes" <<<"$out" && ok "ci-local refuses untracked source before workflow execution" || bad "ci-local missed untracked files"
rm "$ci_repo/untracked-source.txt"
printf '\n.github/workflows/hidden.yml\n' >>"$ci_repo/.gitignore"
git -C "$ci_repo" add .gitignore && git -C "$ci_repo" -c user.email=t@example.com -c user.name=T commit -q -m "chore: ignore generated workflow"
mkdir -p "$ci_repo/.github/workflows"; echo 'name: hidden' >"$ci_repo/.github/workflows/hidden.yml"
out="$(bash "${SKILL}/scripts/ci-local.sh" run "$ci_repo" 2>&1)"; rc=$?
[[ "$rc" != 0 ]] && grep -q "ignored workflow file" <<<"$out" && ok "ci-local refuses ignored workflow injection" || bad "ci-local missed ignored workflows"
rm -rf "$ci_repo"

echo "== doctor"
out="$(cd "$repo" && bash .github/scripts/doctor.sh 2>&1)"; rc=$?
[[ "$rc" == 0 ]] && ok "doctor passes on a fresh install" || { bad "doctor rc=$rc"; echo "$out" >&2; }
grep -q "stacks detected: go" <<<"$out" && ok "doctor reports the detected stack" || bad "doctor stack report"
doctor_rel="${SKILL#"${REPO_ROOT}"/}/scripts/doctor.sh"
out="$(cd "$REPO_ROOT" && bash "$doctor_rel" "$repo" 2>&1)"; rc=$?
[[ "$rc" == 0 ]] && grep -q "doctor: ok" <<<"$out" && ok "doctor works from a relative source path with an external target" || { bad "doctor relative source path rc=$rc"; echo "$out" >&2; }
rm "$repo/.gitleaks.toml"
out="$(cd "$repo" && bash .github/scripts/doctor.sh 2>&1)"; rc=$?
[[ "$rc" == 1 ]] && grep -q "missing: .gitleaks.toml" <<<"$out" && ok "doctor fails when a required file is missing" || bad "doctor missing file rc=$rc"
fresh="$(new_repo '')"
bash "$INSTALL" --target "$fresh" --stack none >/dev/null 2>&1
out="$(cd "$fresh" && bash .github/scripts/doctor.sh 2>&1)"
grep -q "placeholders still present" <<<"$out" && ok "doctor warns about unfilled placeholders" || bad "placeholder warning"
marker="$fresh/doctor-config-command-ran"
# shellcheck disable=SC2016  # Deliberately write literal shell syntax as config data.
printf '\nWARN_LINES=$(touch %s)\n' "$marker" >>"$fresh/.github/engineering-rules.env"
(cd "$fresh" && bash .github/scripts/doctor.sh >/dev/null 2>&1) || true
[[ ! -e "$marker" ]] && ok "doctor parses env data without executing shell expressions" || bad "doctor executed repository config"

e2e_edition() { # <install script> <label>
  local script="$1" label="$2" e2e out rc
  e2e="$(new_repo go/good)"
  bash "$script" --target "$e2e" --org acme --project shop --owner jane --stack go >/dev/null 2>&1
  (cd "$e2e" && mkdir -p src docs/features && echo "# Core" >docs/features/core.md && sed -i.bak 's#src/<module>/\*\*#src/core/**#; s#docs/features/<module>.md#docs/features/core.md#' docs/docs-map.yml && rm -f docs/docs-map.yml.bak)
  git -C "$e2e" add -A && git -C "$e2e" -c user.email=t@example.com -c user.name=T commit -q -m "chore: adopt engineering rules"
  git -C "$e2e" update-ref refs/remotes/origin/main HEAD
  git -C "$e2e" checkout -q -b feat/x
  mkdir -p "$e2e/src/core" && echo "package core" >"$e2e/src/core/x.go"
  echo "More." >>"$e2e/docs/features/core.md"
  printf -- '- Added: core module.\n' >>"$e2e/CHANGELOG.md"
  git -C "$e2e" add -A && git -C "$e2e" -c user.email=t@example.com -c user.name=T commit -q -m "feat: add core"
  out="$(cd "$e2e" && STACK_SKIP_GATES=audit bash .github/scripts/local-proof.sh --title "feat: add core" 2>&1)"; rc=$?
  if [[ "$rc" == 0 ]] && grep -q "| Secret scan .*PASS" <<<"$out" && grep -q "| Stack gates .*PASS" <<<"$out" && grep -q "| docs-check .*PASS" <<<"$out"; then
    ok "${label}: local-proof passes (secret scan, docs-check, policy, size, stack gates)"
  elif grep -q "NOT RUN" <<<"$out" && grep -q "gitleaks\|network" <<<"$out"; then
    skipped "${label}: local-proof end to end (a tool could not be downloaded: no network)"
  else
    bad "${label}: local-proof end to end rc=$rc"; printf '%s\n' "$out" | head -n 20 >&2
  fi
}

echo "== local-proof end to end (all gates in an adopted repository)"
e2e_edition "$INSTALL" "english edition"
echo "== arabic edition (right-to-left docs must pass the same gates)"
e2e_edition "${REPO_ROOT}/skills/engineering-rules-ar/scripts/install.sh" "arabic edition"
arabic="$(new_repo '')"
bash "${REPO_ROOT}/skills/engineering-rules-ar/scripts/install.sh" --target "$arabic" --stack none >/dev/null 2>&1
grep -q "فحص الأسرار" "$arabic/AGENTS.md" && ok "arabic edition installs the Arabic AGENTS.md" || bad "arabic AGENTS.md"
grep -q 'dir="rtl"' "$arabic/AGENTS.md" && ok "installed Arabic docs carry the RTL wrapper" || bad "rtl wrapper"

summary
