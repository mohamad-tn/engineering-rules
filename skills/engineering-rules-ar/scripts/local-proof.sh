#!/usr/bin/env bash
# Run the project gates locally and print a block to paste into the pull
# request as proof. Use it when hosted CI cannot run (no minutes, outage, no
# paid plan). It runs the SAME scripts the CI workflow runs; it does not
# reimplement them.
#
# Usage (from the repository root):
#   bash .github/scripts/local-proof.sh [--base <sha>] [--title "<PR title>"] \
#        [--label <name>]... [--allow-missing] [--out <file>] [--no-stack] [--fast]
# --json prints one JSON document on stdout (the Markdown proof goes to --out or stderr).
# --fast skips build and audit in the stack gates (a quick loop while coding;
# run without it before you ask for review). --no-stack skips the stack gates
# and says so in the proof.
#
# Gates: secret scan, docs-check, policy gates, flag expiry, PR size,
# stack gates (every detected stack), dependency-bot config. A gate that cannot run (tool missing) is reported as
# NOT RUN and makes the script fail, unless --allow-missing is given; a gate
# that did not run is not proof.
# Exit status: 0 when no gate failed and no gate is missing, unless --allow-missing
# explicitly relaxes the exit status. Fast mode may exit 0 for development,
# but JSON still reports ok=false and proof_complete=false for partial results.
set -uo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

_er_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _d in "$_er_dir" "$_er_dir/../scripts"; do
  # shellcheck source=/dev/null
  [[ -f "$_d/load-env.sh" ]] && { . "$_d/load-env.sh"; break; }
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_branch="${DEFAULT_BRANCH:-}"
if [[ -z "$default_branch" ]]; then
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [[ -z "$default_branch" ]]; then
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then default_branch=main
    elif git rev-parse --verify -q origin/master >/dev/null 2>&1; then default_branch=master
    else default_branch=main; fi
  fi
fi
base="" title="" allow_missing=0 out_file="" no_stack=0 fast=0 json=0
labels=()

while (($#)); do
  case "$1" in
    --base) base="${2:?--base needs a sha}"; shift 2 ;;
    --title) title="${2:?--title needs text}"; shift 2 ;;
    --label) labels+=("${2:?--label needs a name}"); shift 2 ;;
    --allow-missing) allow_missing=1; shift ;;
    --out) out_file="${2:?--out needs a path}"; shift 2 ;;
    --no-stack) no_stack=1; shift ;;
    --fast) fast=1; shift ;;
    --json) json=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if ((json)) && ! command -v node >/dev/null 2>&1; then
  echo "--json requires Node.js to serialize the result safely." >&2
  exit 2
fi

# Finds a gate script next to this one (after copying into .github/scripts/)
# or in the package layout (../templates/).
find_script() {
  local name="$1" dir
  for dir in "$here" "${here}/../templates"; do
    [[ -f "${dir}/${name}" ]] && { echo "${dir}/${name}"; return 0; }
  done
  return 1
}

# Profile (thresholds, required stack gates) and tool pins are shared with CI.
profile="${ENGINEERING_RULES_ENV:-.github/engineering-rules.env}"
er_load_env "$profile"
# Tool pins (versions and checksums) are shared with the CI scripts.
pins="${TOOL_PINS_FILE:-.github/tool-pins.env}"
er_load_env "$pins"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside a git repository." >&2; exit 2; }
head_sha="$(git rev-parse HEAD)"
if [[ -z "$base" ]]; then
  base="$(git merge-base "origin/${default_branch}" HEAD 2>/dev/null || true)"
fi
[[ -n "$base" ]] || { echo "Cannot find a base commit. Pass --base <sha> (is origin/${default_branch} fetched?)." >&2; exit 2; }
[[ -n "$title" ]] || title="$(git log -1 --format=%s)"
if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "Uncommitted tracked or untracked changes: results belong to a commit. Commit or remove them first." >&2
  exit 2
fi

if command -v node >/dev/null 2>&1; then
  labels_json="$(node -e 'process.stdout.write(JSON.stringify(process.argv.slice(1)))' "${labels[@]}")"
else
  labels_json='[]'
  if ((${#labels[@]})); then echo "Node.js is required to serialize pull-request labels safely." >&2; exit 2; fi
fi

results=() details=() jrows=()
failed=0 missing=0

# gate <name> <command-description> <command...>
gate() {
  local name="$1" shown="$2"
  shift 2
  local log status
  log="$(mktemp)"
  "$@" >"$log" 2>&1
  status=$?
  if ((status == 0)); then
    results+=("| ${name} | \`${shown}\` | PASS |")
    jrows+=("${name}	PASS	${shown}")
  else
    results+=("| ${name} | \`${shown}\` | **FAIL** (exit ${status}) |")
    jrows+=("${name}	FAIL	${shown}")
    failed=1
  fi
  details+=("<details><summary>${name} output (last 40 lines)</summary>"$'\n\n```text\n'"$(tail -n 40 "$log")"$'\n```\n\n</details>')
  rm -f "$log"
}

not_run() {
  results+=("| $1 | \`$2\` | **NOT RUN** ($3) |")
  jrows+=("$1	NOT_RUN	$2")
  missing=1
}

export BASE_SHA="$base" HEAD_SHA="$head_sha" PR_TITLE="$title" PR_LABELS_JSON="$labels_json"

# Secret scan.
if gitleaks_bin="$(bash "${here}/ensure-tool.sh" gitleaks 2>/dev/null)"; then
  gate "Secret scan" "gitleaks-scan.sh" bash "${here}/gitleaks-scan.sh" .gitleaks.toml "$gitleaks_bin"
else
  not_run "Secret scan" "gitleaks-scan.sh" "gitleaks not installed or not pinned"
fi

# docs-check.
if script="$(find_script docs-check.sh)"; then
  gate "docs-check" "docs-check.sh" bash "$script" .
else
  not_run "docs-check" "docs-check.sh" "script not found"
fi

# Policy gates and flag expiry.
if command -v node >/dev/null 2>&1; then
  gate "Policy gates" "policy-gates.mjs" node "${here}/policy-gates.mjs" .
  gate "Flag expiry" "feature-flag-expiry.mjs" node "${here}/feature-flag-expiry.mjs" .
else
  not_run "Policy gates" "policy-gates.mjs" "node not installed"
  not_run "Flag expiry" "feature-flag-expiry.mjs" "node not installed"
fi

# PR size.
if script="$(find_script pr-size-check.sh)"; then
  gate "PR size" "pr-size-check.sh" bash "$script"
else
  not_run "PR size" "pr-size-check.sh" "script not found"
fi

# Stack gates (build, tests, lint, types, audit of the detected stacks).
if ((no_stack)); then
  results+=("| Stack gates | \`stack-gates.sh\` | SKIPPED (--no-stack; not proof) |")
  jrows+=("Stack gates	SKIPPED	stack-gates.sh")
  missing=1
elif [[ -f "${here}/stack-gates.sh" ]]; then
  stack_args=(--root .)
  ((fast)) && stack_args+=(--fast)
  stack_log="$(mktemp)"
  bash "${here}/stack-gates.sh" "${stack_args[@]}" >"$stack_log" 2>&1
  stack_status=$?
  case "$stack_status" in
    0)
      if ((fast)); then
        results+=("| Stack gates | \`stack-gates.sh --fast\` | SKIPPED (build/audit; development only, not full proof) |")
        jrows+=("Stack gates	SKIPPED	stack-gates.sh --fast")
      else
        results+=("| Stack gates | \`stack-gates.sh\` | PASS |"); jrows+=("Stack gates	PASS	stack-gates.sh")
      fi ;;
    3) results+=("| Stack gates | \`stack-gates.sh\` | N/A (no supported stack found) |"); jrows+=("Stack gates	NA	stack-gates.sh") ;;
    *) results+=("| Stack gates | \`stack-gates.sh\` | **FAIL** (exit ${stack_status}) |"); jrows+=("Stack gates	FAIL	stack-gates.sh"); failed=1 ;;
  esac
  details+=("<details><summary>Stack gates output (last 60 lines)</summary>"$'\n\n```text\n'"$(tail -n 60 "$stack_log")"$'\n```\n\n</details>')
  rm -f "$stack_log"
else
  not_run "Stack gates" "stack-gates.sh" "script not found"
fi

# Dependency-bot config (only when the repository uses it).
if [[ -f renovate.json ]]; then
  gate "Renovate config" "renovate-config-check.sh" bash "${here}/renovate-config-check.sh" .
fi

{
  echo "### Local gate proof (hosted CI was not used)"
  echo
  echo "- Commit: \`${head_sha}\` (base \`${base}\`)"
  echo "- Title checked: ${title}"
  echo "- Run at: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm)"
  echo
  echo "| Gate | Command | Result |"
  echo "|---|---|---|"
  printf '%s\n' "${results[@]}"
  echo
  printf '%s\n' "${details[@]}"
} | {
  if ((json)); then
    if [[ -n "$out_file" ]]; then cat >"$out_file"; else cat >&2; fi
  elif [[ -n "$out_file" ]]; then tee "$out_file"
  else cat; fi
}

if ((json)); then
  stack_mode=full
  if ((no_stack)); then stack_mode=skipped
  elif ((fast)); then stack_mode=fast; fi
  printf '%s\n' "${jrows[@]}" | node -e '
    const rows = require("fs").readFileSync(0, "utf8").split("\n").filter(Boolean).map((l) => l.split("\t"));
    const gates = rows.map(([gate, status, command]) => ({ gate, status, command }));
    const stack_mode = process.argv[3];
    const proof_complete = gates.every((g) => g.status === "PASS" || g.status === "NA");
    const execution_ok = gates.every((g) => g.status === "PASS" || g.status === "NA" ||
      (stack_mode === "fast" && g.gate === "Stack gates" && g.status === "SKIPPED"));
    process.stdout.write(JSON.stringify({ ok: proof_complete, execution_ok, proof_complete,
      stack_mode, commit: process.argv[1], base: process.argv[2], gates }, null, 2) + "\n");
  ' "$head_sha" "$base" "$stack_mode"
fi

if ((failed)); then exit 1; fi
if ((missing)) && ((!allow_missing)); then
  echo "One or more gates did not run. Install the tool or pass --allow-missing and say so in the pull request." >&2
  exit 1
fi
exit 0
