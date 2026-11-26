#!/usr/bin/env bash
# Checks that a repository has adopted the engineering rules correctly.
#   bash .github/scripts/doctor.sh [repo dir]
# Prints one line per check: [PASS], [WARN] (fix soon) or [FAIL] (fix now).
# Exit status 1 when anything FAILs. It changes nothing.
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

repo="$(cd "${1:-.}" && pwd -P)" || { echo "doctor: repository directory is not accessible." >&2; exit 2; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$repo" || exit 2
# The loader parses KEY=VALUE data; it does not execute the repository's env files.
# shellcheck source=load-env.sh
. "${script_dir}/load-env.sh"
fails=0 warns=0

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; warns=$((warns + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; fails=$((fails + 1)); }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 && pass "inside a git repository" || fail "not a git repository"

echo "--- files"
required=(
  AGENTS.md CHANGELOG.md renovate.json .gitleaks.toml
  .github/PULL_REQUEST_TEMPLATE.md .github/CODEOWNERS .github/workflows/project-gates.yml
  .github/tool-pins.env .github/engineering-rules.env
  .github/scripts/local-proof.sh .github/scripts/stack-gates.sh .github/scripts/docs-check.sh
  .github/scripts/pr-size-check.sh .github/scripts/policy-gates.mjs .github/scripts/gitleaks-scan.sh
  .github/docs-check/required-docs.json docs/docs-map.yml docs/README.md
)
for f in "${required[@]}"; do
  [[ -e "$f" ]] && pass "$f" || fail "missing: $f"
done
for f in .github/scripts/*.sh; do
  [[ -x "$f" ]] || fail "not executable: $f (chmod +x)"
done

echo "--- placeholders"
left="$(grep -rlE '<(owner|org|project|infra-commit-sha)>' AGENTS.md renovate.json .github/CODEOWNERS .github/tool-pins.env .github/workflows 2>/dev/null || true)"
if [[ -z "$left" ]]; then
  pass "no <owner>, <org> or <project> placeholders left in the key files"
else
  warn "placeholders still present in: $(echo "$left" | tr '\n' ' ')"
fi

echo "--- tool pins"
if [[ -f .github/tool-pins.env ]]; then
  empties="$(
    unset GITLEAKS_VERSION GITLEAKS_SHA256 LYCHEE_VERSION LYCHEE_SHA256 MARKDOWNLINT_CLI2_VERSION RENOVATE_VERSION
    er_load_env .github/tool-pins.env
    for v in GITLEAKS_VERSION GITLEAKS_SHA256 LYCHEE_VERSION LYCHEE_SHA256 MARKDOWNLINT_CLI2_VERSION RENOVATE_VERSION; do
      [[ -n "${!v:-}" ]] || echo "$v"
    done
  )"
  if [[ -z "$empties" ]]; then
    pass "tool pins are filled"
  else
    for v in $empties; do fail "empty pin: ${v} in .github/tool-pins.env"; done
  fi
fi

echo "--- history policy"
if ( unset SECRET_SCAN_FROM; er_load_env .github/engineering-rules.env; [[ -n "${SECRET_SCAN_FROM:-}" ]] ); then
  warn "SECRET_SCAN_FROM is set: the secret scan skips older history. Make sure old secrets were rotated and an ADR records this."
else
  pass "the secret scan covers the full history"
fi

echo "--- profile and stacks"
if [[ -f .github/engineering-rules.env ]]; then
  (
    unset WARN_LINES FAIL_LINES STACK_REQUIRE STACK_STRICT
    er_load_env .github/engineering-rules.env
    echo "profile values: WARN_LINES=${WARN_LINES:-?} FAIL_LINES=${FAIL_LINES:-?} STACK_REQUIRE=${STACK_REQUIRE:-?} STACK_STRICT=${STACK_STRICT:-?}"
  )
fi
if [[ -f .github/scripts/stack-gates.sh ]]; then
  stacks="$(bash .github/scripts/stack-gates.sh --root . --list 2>/dev/null || true)"
  if [[ -z "$stacks" ]]; then
    warn "no supported stack detected (stack gates will report N/A)"
  else
    pass "stacks detected: $(echo "$stacks" | awk '{printf "%s(%s) ", $1, $2}')"
    while read -r eng _; do
      case "$eng" in
        node) tool=node ;; dotnet) tool=dotnet ;; php) tool=php ;; flutter) tool=dart ;;
        python) tool=python3 ;; java) tool=java ;; go) tool=go ;; rust) tool=cargo ;; ruby) tool=ruby ;;
        cpp) tool=cmake ;; docker) tool=hadolint ;; terraform) tool=tofu ;; swift) tool=swift ;;
        *) tool="" ;;
      esac
      [[ -z "$tool" ]] && continue
      command -v "$tool" >/dev/null 2>&1 && pass "toolchain for ${eng}: ${tool} found" || warn "toolchain for ${eng}: ${tool} not on PATH (its gates will be NOT RUN here)"
    done <<<"$stacks"
  fi
  for wf in .github/workflows/stack-*.yml; do
    [[ -e "$wf" ]] && pass "workflow ${wf#.github/workflows/}"
  done
fi

echo "--- local tools"
for t in git bash node; do command -v "$t" >/dev/null 2>&1 && pass "$t" || fail "$t is required"; done
command -v jq >/dev/null 2>&1 && pass "jq" || warn "jq missing (needed for PR labels in the size gate and ci-local.sh)"
{ command -v gitleaks >/dev/null 2>&1 && pass "gitleaks on PATH"; } || pass "gitleaks will be downloaded from the pinned release when needed"
hook=".git/hooks/pre-commit"
if [[ -f "$hook" ]] && grep -qi gitleaks "$hook"; then pass "pre-commit hook with gitleaks installed"; else warn "pre-commit hook not installed (run: pre-commit install)"; fi

echo "--- repository settings (branch protection)"
if command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
  branch="$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')"
  branch="${branch:-main}"
  if prot="$(gh api "repos/{owner}/{repo}/branches/${branch}/protection" 2>/dev/null)"; then
    pass "branch protection is on for ${branch}"
    jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' <<<"$prot" >/dev/null 2>&1 && pass "code-owner review required" || warn "require code-owner reviews"
    jq -e '(.required_status_checks.contexts // []) | index("project-gates / gates") != null' <<<"$prot" >/dev/null 2>&1 \
      && pass "required check: project-gates / gates" \
      || warn "require the exact project-gates / gates status check (other checks do not prove these gates ran)"
  else
    warn "no branch protection found on ${branch} (or no permission to read it): see references/workflow.md"
  fi
else
  warn "gh CLI or a remote is missing: check branch protection by hand (references/workflow.md)"
fi

echo
if ((fails)); then
  echo "doctor: ${fails} problem(s) to fix, ${warns} warning(s)."
  exit 1
fi
echo "doctor: ok (${warns} warning(s))."
