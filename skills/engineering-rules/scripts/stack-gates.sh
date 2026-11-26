#!/usr/bin/env bash
# Stack gates: detect the stacks in a repository and run the standard gates
# (deps, format, lint, types, test, build, audit, plus stack extras) for each.
#
#   bash stack-gates.sh [--root <repo dir>] [--only <gate,gate>] [--fast]
#                       [--strict] [--list] [--json] [--quiet] [--engine <engine,engine>]
#                       [--dirs "<engine>:<dir> ..."]
#                       [--report <file>]
#
# Stacks: node (Node.js, Next.js, React, React Native/Expo, Vue, Angular,
# Svelte, NestJS, Express...), dotnet, php (Laravel, Symfony...), flutter
# (Flutter and Dart), python (Django, FastAPI, Flask...), java (Maven, Gradle,
# Spring...), go, rust, ruby (Rails...). Monorepos: every project found runs.
#
# A gate is PASS, FAIL, SKIP (nothing to run), NOT RUN (a tool or the network
# is missing) or WARN. The gates in STACK_REQUIRE must PASS: for them SKIP and
# NOT RUN count as failures, so "nothing ran" never reads as green.
#
# Configuration (environment, or .github/engineering-rules.env):
#   STACK_REQUIRE        gates that must pass         (default: deps,test,build)
#   STACK_STRICT=1       also require format,lint,types,audit
#   STACK_FAST=1         skip build, audit and e2e    (STACK_FAST_SKIP to change)
#   STACK_ONLY=a,b       run only these gates
#   STACK_SKIP_GATES=a   never run these gates
#   STACK_CMD_<GATE>     replace a gate's command, e.g. STACK_CMD_TEST="make test"
#   STACK_EXCLUDE        space-separated path prefixes to ignore
#   STACK_INCLUDE_SAMPLES=1  also gate examples/, docs/, samples/, fixtures/... folders
#   STACK_GATE_TIMEOUT   seconds per gate             (default: 1800)
#   AUDIT_LEVEL          minimum severity that fails an audit (default: high)
# Exit status: 0 when every project passes and every required gate passed.
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
root="." only="" report="" dirs="" list_only=0 engines="" json=0

while (($#)); do
  case "$1" in
    --root) root="${2:?--root needs a directory}"; shift 2 ;;
    --only) only="${2:?--only needs a list}"; shift 2 ;;
    --fast) export STACK_FAST=1; shift ;;
    --strict) export STACK_STRICT=1; shift ;;
    --list) list_only=1; shift ;;
    --json) json=1; shift ;;
    --quiet) export STACK_QUIET=1; shift ;;
    --engine) engines="${2:?--engine needs a list}"; shift 2 ;;
    --dirs) dirs="${2:?--dirs needs a list}"; shift 2 ;;
    --report) report="${2:?--report needs a file}"; shift 2 ;;
    -h | --help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

root="$(cd "$root" && pwd -P)" || { echo "stack-gates: root is not an accessible directory." >&2; exit 2; }
# --json: stdout carries ONLY the JSON document (for agents and tools); every log goes to stderr.
if ((json)); then exec 3>&1 1>&2; fi
cd "$root" || exit 2
pins="${ENGINEERING_RULES_ENV:-${root}/.github/engineering-rules.env}"
er_load_env "$pins"
[[ -n "$only" ]] && export STACK_ONLY="$only"
export STACK_ROOT="$root"

# --- detection -------------------------------------------------------------
vendored='(^|/)(node_modules|vendor|third_party|\.venv|venv|env|dist|build|target|bin|obj|\.dart_tool|Pods)/'
# Sample, documentation and test-data folders are not projects to gate (a repository
# with examples/ would otherwise run every example). STACK_INCLUDE_SAMPLES=1 includes them.
samples='(^|/)(examples?|samples?|demos?|docs?|fixtures|testdata|benchmarks?|tutorials?)/'

list_files() {
  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$root" ls-files --cached --others --exclude-standard
  else
    (cd "$root" && find . -type f -not -path './.git/*' | sed 's#^\./##')
  fi
}

# detect: prints "<engine>\t<dir>" lines, sorted and de-duplicated.
# (Indexed arrays only: macOS ships bash 3.2 and has no associative arrays.)
detect() {
  local f dir base prefix excluded
  local raw=()
  while IFS= read -r f; do
    [[ "$f" =~ $vendored ]] && continue
    if [[ "${STACK_INCLUDE_SAMPLES:-0}" != "1" && "$f" =~ $samples ]]; then continue; fi
    excluded=0
    for prefix in ${STACK_EXCLUDE:-}; do [[ "$f" == "$prefix"* ]] && excluded=1; done
    ((excluded)) && continue
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    case "$base" in
      package.json) raw+=("node	${dir}") ;;
      *.sln | *.slnx) raw+=("dotnet	${dir}") ;;
      *.csproj) raw+=("dotnet?	${dir}") ;;
      composer.json) raw+=("php	${dir}") ;;
      pubspec.yaml) raw+=("flutter	${dir}") ;;
      pyproject.toml | requirements.txt | Pipfile | setup.py) raw+=("python?	${dir}") ;;
      pom.xml | build.gradle | build.gradle.kts | settings.gradle | settings.gradle.kts) raw+=("java	${dir}") ;;
      go.mod) raw+=("go	${dir}") ;;
      Cargo.toml) raw+=("rust	${dir}") ;;
      Gemfile) raw+=("ruby	${dir}") ;;
      Package.swift) raw+=("swift	${dir}") ;;
      CMakeLists.txt) raw+=("cpp	${dir}") ;;
      Dockerfile | Dockerfile.* | *.Dockerfile) raw+=("docker	${dir}") ;;
      *.tf) raw+=("terraform	${dir}") ;;
    esac
  done < <(list_files)
  ((${#raw[@]})) || return 0

  # unique candidates
  local cands=()
  while IFS= read -r f; do cands+=("$f"); done < <(printf '%s\n' "${raw[@]}" | sort -u)

  local key engine d other od keep up
  for key in "${cands[@]}"; do
    engine="${key%%	*}"
    d="${key#*	}"
    keep=1
    case "$engine" in
      "dotnet?")
        # a csproj counts only when no solution sits at or above it
        for other in "${cands[@]}"; do
          [[ "${other%%	*}" == "dotnet" ]] || continue
          od="${other#*	}"
          if [[ "$od" == "." || "$d" == "$od" || "$d" == "$od"/* ]]; then keep=0; fi
        done
        engine="dotnet"
        ;;
      "python?")
        # a python project needs Python sources (skips docs-only requirement files)
        if [[ -z "$(find "${root}/${d}" -maxdepth 2 -name '*.py' -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ]]; then keep=0; fi
        engine="python"
        ;;
      java | rust | php | ruby | dotnet | swift | cpp | python)
        # nested modules belong to the project above them
        for other in "${cands[@]}"; do
          [[ "${other%%	*}" == "$engine" ]] || continue
          od="${other#*	}"
          [[ "$od" == "$d" ]] && continue
          if [[ "$od" == "." || "$d" == "$od"/* ]]; then keep=0; fi
        done
        ;;
      docker)
        # one Dockerfile run per directory is enough; keep as is
        ;;
      terraform)
        # one run per directory that holds .tf files
        ;;
      node)
        # workspace members are run by the workspace root
        up="$d"
        while [[ "$up" != "." && "$up" != "/" ]]; do
          up="$(dirname "$up")"
          if [[ -f "${root}/${up}/package.json" ]] && { grep -q '"workspaces"' "${root}/${up}/package.json" || [[ -f "${root}/${up}/pnpm-workspace.yaml" ]]; }; then
            keep=0
          fi
        done
        ;;
    esac
    ((keep)) && printf '%s\t%s\n' "$engine" "$d"
  done | sort -u
}

if [[ -n "$dirs" ]]; then
  projects="$(for p in $dirs; do printf '%s\t%s\n' "${p%%:*}" "${p#*:}"; done)"
elif [[ -f "${root}/.github/engineering-rules.stacks" ]]; then
  projects="$(grep -vE '^\s*(#|$)' "${root}/.github/engineering-rules.stacks" | while IFS=: read -r e d; do printf '%s\t%s\n' "$e" "${d:-.}"; done)"
else
  projects="$(detect)"
fi

if [[ -n "$engines" && -n "$projects" ]]; then
  projects="$(awk -F'\t' -v e=",${engines// /}," 'index(e, "," $1 ",") > 0' <<<"$projects")"
fi

if [[ -z "$projects" ]]; then
  echo "stack-gates: no supported stack found in ${root}." >&2
  echo "  Supported: node, dotnet, php, flutter, python, java, go, rust, ruby." >&2
  echo "  Nothing was checked, so this is not a pass." >&2
  exit 3
fi

# Validate the explicit map too: an invalid engine or inaccessible/outside
# directory is an input error, not an empty successful result.
while IFS=$'\t' read -r engine dir; do
  case "$engine" in
    node|dotnet|php|flutter|python|java|go|rust|ruby|swift|cpp|docker|terraform) ;;
    *) echo "stack-gates: unsupported engine: ${engine}" >&2; exit 2 ;;
  esac
  resolved="$(cd "${root}/${dir}" && pwd -P)" || exit 2
  [[ "$resolved" == "$root" || "$resolved" == "$root"/* ]] || { echo "stack-gates: project directory is outside root." >&2; exit 2; }
done <<<"$projects"

if ((list_only)); then
  printf '%s\n' "$projects" | awk -F'\t' '{printf "%-8s %s\n", $1, $2}'
  exit 0
fi

# --- run ---------------------------------------------------------------------
STACK_RESULTS="$(mktemp)"
export STACK_RESULTS
trap 'rm -f "$STACK_RESULTS"' EXIT
# shellcheck source=stacks/lib.sh
. "${here}/stacks/lib.sh"

while IFS=$'\t' read -r engine dir; do
  engine_file="${here}/stacks/${engine}.sh"
  [[ -f "$engine_file" ]] || { echo "no engine for ${engine}" >&2; continue; }
  # shellcheck disable=SC1090
  . "$engine_file"
  # shellcheck disable=SC2034  # read by lib.sh when recording results
  STACK_CUR_ENGINE="$engine"
  # shellcheck disable=SC2034
  STACK_CUR_DIR="$dir"
  echo "== ${engine} · ${dir}"
  before_rows="$(wc -l <"$STACK_RESULTS")"
  ( cd "${root}/${dir}" && "run_${engine}" "${root}/${dir}" ) || {
    fail "engine" "the ${engine} engine stopped unexpectedly"
  }
  [[ "$(wc -l <"$STACK_RESULTS")" != "$before_rows" ]] || fail "engine" "the ${engine} engine recorded no gate results"
  echo
done <<<"$projects"

# --- verdict -------------------------------------------------------------------
require="${STACK_REQUIRE:-deps,test,build}"
[[ "${STACK_STRICT:-0}" == "1" ]] && require="${require},format,lint,types,audit"
[[ -n "${STACK_ONLY:-}" ]] && require="$STACK_ONLY"
# What the user switched off on purpose is not "missing": drop it from the list.
drop_from_require() {
  local item kept=""
  for item in ${require//,/ }; do
    in_list "$item" "$1" || kept="${kept:+${kept},}${item}"
  done
  require="$kept"
}
drop_from_require "${STACK_SKIP_GATES:-}"
[[ "${STACK_FAST:-0}" == "1" ]] && drop_from_require "${STACK_FAST_SKIP:-build,audit,e2e}"
[[ "${STACK_SKIP_INSTALL:-0}" == "1" ]] && drop_from_require "deps"

verdict="$(awk -F'\t' -v require="$require" '
  BEGIN { n = split(require, r, ","); for (i = 1; i <= n; i++) need[r[i]] = 1 }
  { key = $1 "\t" $2; rows[++total] = $0; st[key "\t" $3] = $4; why[key "\t" $3] = $5; proj[key] = 1 }
  END {
    bad = 0
    for (i = 1; i <= total; i++) {
      split(rows[i], c, "\t")
      if (c[4] == "FAIL") bad++
      printf "%s\t%s\t%s\t%s\t%s\n", c[1], c[2], c[3], c[4], c[5] > "/dev/stderr"
    }
    for (p in proj) for (g in need) {
      k = p "\t" g
      if (!(k in st) || st[k] == "SKIP" || st[k] == "NOTRUN") {
        split(p, pc, "\t")
        printf "REQUIRED\t%s\t%s\t%s\t%s\n", pc[1], pc[2], g, ((k in st) ? why[k] : "no gate result recorded")
        bad++
      }
    }
    print bad
  }' "$STACK_RESULTS" 2>"${STACK_RESULTS}.rows")"

failures="${verdict##*$'\n'}"
missing="$(grep -c '^REQUIRED' <<<"$verdict" || true)"

{
  echo "### Stack gates"
  echo
  echo "| Stack | Project | Gate | Result | Detail |"
  echo "|---|---|---|---|---|"
  awk -F'\t' '{ printf "| %s | `%s` | %s | %s | %s |\n", $1, $2, $3, ($4=="NOTRUN"?"NOT RUN":$4), $5 }' "${STACK_RESULTS}.rows"
  echo
  if ((missing > 0)); then
    echo "Required gates that did not run (${require}):"
    grep '^REQUIRED' <<<"$verdict" | awk -F'\t' '{ printf "- %s `%s`: %s (%s)\n", $2, $3, $4, $5 }'
    echo
  fi
} | tee ${report:+"$report"}

if ((json)); then
  node -e '
    const fs = require("fs");
    const rows = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => l.split("\t"));
    const projects = [];
    for (const [engine, dir, gate, status, detail] of rows) {
      let p = projects.find((x) => x.engine === engine && x.dir === dir);
      if (!p) { p = { engine, dir, gates: [] }; projects.push(p); }
      p.gates.push({ gate, status, detail });
    }
    const missing = process.argv[2].split("\n").filter((l) => l.startsWith("REQUIRED")).map((l) => {
      const [, engine, dir, gate, reason] = l.split("\t");
      return { engine, dir, gate, reason };
    });
    const failed = projects.flatMap((p) => p.gates.filter((g) => g.status === "FAIL").map((g) => ({ engine: p.engine, dir: p.dir, gate: g.gate })));
    process.stdout.write(JSON.stringify({ ok: process.argv[3] === "0", required: process.argv[4].split(",").filter(Boolean), failed, missingRequired: missing, projects }, null, 2) + "\n");
  ' "${STACK_RESULTS}.rows" "$verdict" "$failures" "$require" >&3
fi
rm -f "${STACK_RESULTS}.rows"

if ((failures > 0)); then
  echo "stack-gates: FAILED (${failures} problem(s))."
  exit 1
fi
echo "stack-gates: all gates passed (required: ${require})."
