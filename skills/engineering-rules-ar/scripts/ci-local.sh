#!/usr/bin/env bash
# Run a repository's OWN workflow files on your machine when hosted CI is
# unavailable (outage, no minutes). The workflow files stay the only source of
# the CI commands: nektos/act runs them in host mode (no containers). Nothing
# here re-implements a gate.
#
#   bash ci-local.sh run   <repo dir> [--pr <number>] [--post] [--label <name>]...
#   bash ci-local.sh event <repo dir> [--pr <number>] [--label <name>]...
#   bash ci-local.sh results <act log>
#
# run      Runs the pull_request workflows for the committed HEAD of a clean
#          worktree and stores evidence in $CI_EVIDENCE_DIR/<repo>/<sha>-<time>/.
#   --pr   Level 2 (forge API reachable): the event is the real PR payload
#          (needs `gh`); HEAD must be the PR head.
#   --post Posts one `ci-local/<workflow>/<job>` commit status per job (needs --pr).
#          Without --pr the event is built offline from origin/<default>...HEAD
#          (level 3, forge unreachable): evidence only. Steps that call the
#          forge fail offline, so level-3 results are advisory.
# event    Prints the event payload that `run` would use.
# results  Prints "<workflow>\t<job>\t<success|failure>" for each finished job.
#
# Env: CI_LOCAL_REPOS (space-separated allowlist of repo names; empty = any),
#      CI_LOCAL_RUNNER_LABELS (JSON for the CI_RUNNER variable; default
#      ["self-hosted","linux","x64"]), CI_LOCAL_DEFAULT_BRANCH (main),
#      CI_EVIDENCE_DIR (~/ci-evidence), ACT_VERSION + ACT_SHA256 (only needed
#      when `act` is not on PATH), CI_LOCAL_EXTRA_ENV (space-separated NAME=value
#      pairs passed to the jobs).
# Needs: git, jq, act (or the pin above). Needs `gh` for --pr / --post.
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
readonly DEFAULT_BRANCH="${CI_LOCAL_DEFAULT_BRANCH:-main}"
readonly RUNNER_LABELS="${CI_LOCAL_RUNNER_LABELS:-[\"self-hosted\",\"linux\",\"x64\"]}"
readonly EVIDENCE_DIR="${CI_EVIDENCE_DIR:-${HOME}/ci-evidence}"
readonly CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/engineering-rules-skill/ci-local"

die() {
  echo "ci-local: $*" >&2
  exit 1
}

# repo_slug <dir>: prints "<owner>/<name>" from the origin URL.
repo_slug() {
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null)" || die "$1 has no origin remote"
  url="${url%.git}"
  url="$(printf '%s' "$url" | sed -E 's#^(git@[^:]+:|https?://[^/]+/|ssh://[^/]+/)##')"
  [[ "$url" == */* ]] || die "cannot read owner/name from origin: $url"
  printf '%s\n' "$url"
}

check_allowed() {
  local name="${1##*/}" allowed
  [[ -z "${CI_LOCAL_REPOS:-}" ]] && return 0
  for allowed in $CI_LOCAL_REPOS; do
    [[ "$allowed" == "$name" ]] && return 0
  done
  die "${name} is not in CI_LOCAL_REPOS (${CI_LOCAL_REPOS})"
}

require_clean() {
  [[ -z "$(git -C "$1" status --porcelain --untracked-files=no)" ]] ||
    die "uncommitted changes in $1: commit them first, results belong to a commit"
}

# event_json <dir> <slug> <pr number or empty> <labels...>
event_json() {
  local dir="$1" slug="$2" pr="$3"
  shift 3
  local head labels owner name repository
  head="$(git -C "$dir" rev-parse HEAD)"
  labels="$(printf '%s\n' "$@" | jq -R 'select(length > 0) | {name: .}' | jq -s .)"
  owner="${slug%%/*}"
  name="${slug##*/}"
  repository="$(jq -n --arg o "$owner" --arg r "$name" --arg b "$DEFAULT_BRANCH" \
    '{name: $r, full_name: ($o + "/" + $r), default_branch: $b, owner: {login: $o}}')"
  if [[ -n "$pr" ]]; then
    local payload
    payload="$(gh api "repos/${slug}/pulls/${pr}")"
    [[ "$(jq -r .head.sha <<<"$payload")" == "$head" ]] ||
      die "HEAD ${head} is not the head of PR #${pr}; check out the PR head first"
    jq -n --argjson pr "$payload" --argjson repository "$repository" \
      '{action: "synchronize", number: $pr.number, pull_request: $pr, repository: $repository}'
    return
  fi
  local base branch title
  base="$(git -C "$dir" merge-base "origin/${DEFAULT_BRANCH}" HEAD)"
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  title="$(git -C "$dir" log -1 --format=%s)"
  jq -n --arg head "$head" --arg base "$base" --arg branch "$branch" --arg title "$title" \
    --arg default "$DEFAULT_BRANCH" --argjson labels "$labels" --argjson repository "$repository" '{
      action: "synchronize", number: 0, repository: $repository,
      pull_request: {number: 0, title: $title, body: "", draft: false, labels: $labels,
        head: {sha: $head, ref: $branch}, base: {sha: $base, ref: $default}}}'
}

results() {
  # act pads "[workflow/job]" with spaces when jobs run in parallel.
  sed -nE 's/^\[([^/]+)\/(.*[^ ]) *\] 🏁  Job (succeeded|failed)$/\1\t\2\t\3/p' "$1" |
    sed -e 's/\tsucceeded$/\tsuccess/' -e 's/\tfailed$/\tfailure/'
}

# Prints the act binary: PATH first, then the pinned release.
find_act() {
  if command -v act >/dev/null 2>&1; then
    command -v act
    return
  fi
  [[ -n "${ACT_VERSION:-}" && -n "${ACT_SHA256:-}" ]] ||
    die "act is not installed. Install nektos/act, or set ACT_VERSION and ACT_SHA256."
  local dest="${CACHE_DIR}/act-${ACT_VERSION}"
  if [[ ! -x "${dest}/act" ]]; then
    bash "${here}/install-release-tool.sh" \
      "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/act_Linux_x86_64.tar.gz" \
      "$ACT_SHA256" act "$dest" >&2
  fi
  echo "${dest}/act"
}

run() {
  local dir="$1" pr="$2" post="$3"
  shift 3
  local slug name sha out act
  slug="$(repo_slug "$dir")"
  name="${slug##*/}"
  check_allowed "$name"
  require_clean "$dir"
  [[ "$post" == "false" || -n "$pr" ]] || die "--post needs --pr (statuses go to a PR head through the API)"
  sha="$(git -C "$dir" rev-parse HEAD)"
  out="${EVIDENCE_DIR}/${name}/${sha:0:12}-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$out" "$CACHE_DIR"
  : >"${CACHE_DIR}/gitconfig"
  event_json "$dir" "$slug" "$pr" "$@" >"${out}/event.json"
  act="$(find_act)"

  local args=(pull_request --eventpath "${out}/event.json" --workflows .github/workflows
    --var "CI_RUNNER=${RUNNER_LABELS}"
    -P self-hosted=-self-hosted -P ubuntu-latest=-self-hosted -P ubuntu-24.04=-self-hosted -P ubuntu-22.04=-self-hosted
    --env LANG=C.UTF-8
    # An empty global git config: the caller's signing or credential settings
    # must not change what tests that commit see.
    --env "GIT_CONFIG_GLOBAL=${CACHE_DIR}/gitconfig")
  local pair
  for pair in ${CI_LOCAL_EXTRA_ENV:-}; do args+=(--env "$pair"); done
  if [[ -n "$pr" ]]; then
    GITHUB_TOKEN="$(gh auth token)"
    export GITHUB_TOKEN
    args+=(--secret GITHUB_TOKEN)
  fi
  # One job at a time: parallel jobs race on act's shared action clones.
  args+=(--concurrent-jobs 1 --action-offline-mode)

  {
    echo "repo=${slug}"
    echo "sha=${sha}"
    echo "pr=${pr:-none (offline)}"
    echo "host=$(hostname)"
    echo "started=$(date -u +%FT%TZ)"
  } >"${out}/meta.txt"
  local status=0
  (cd "$dir" && "$act" "${args[@]}") >"${out}/act.log" 2>&1 || status=$?
  echo "ended=$(date -u +%FT%TZ)" >>"${out}/meta.txt"
  echo "act_exit=${status}" >>"${out}/meta.txt"
  results "${out}/act.log" >"${out}/results.tsv"
  [[ -s "${out}/results.tsv" ]] || { echo "no job finished; see ${out}/act.log" >&2; exit 1; }

  if [[ "$post" == "true" ]]; then
    local workflow job state
    while IFS=$'\t' read -r workflow job state; do
      gh api -X POST "repos/${slug}/statuses/${sha}" \
        -f state="$state" -f context="ci-local/${workflow}/${job}" \
        -f description="workflow files replayed locally with act" >/dev/null
    done <"${out}/results.tsv"
  fi
  awk -F '\t' '{ printf "%-8s %s / %s\n", $3, $1, $2 }' "${out}/results.tsv"
  echo "evidence: ${out}"
  return "$status"
}

cmd="${1:-}"
case "$cmd" in
  run | event)
    dir="${2:?usage: $0 ${cmd} <repo dir> [--pr <number>] [--post] [--label <name>]...}"
    shift 2
    pr="" post="false" labels=()
    while (($#)); do
      case "$1" in
        --pr) pr="${2:?--pr needs a number}"; shift 2 ;;
        --post) post="true"; shift ;;
        --label) labels+=("${2:?--label needs a name}"); shift 2 ;;
        *) die "unknown option $1" ;;
      esac
    done
    [[ -z "$pr" || "$pr" =~ ^[0-9]+$ ]] || die "--pr must be a number"
    if [[ "$cmd" == "event" ]]; then
      slug="$(repo_slug "$dir")"
      check_allowed "${slug##*/}"
      event_json "$dir" "$slug" "$pr" "${labels[@]}"
    else
      run "$dir" "$pr" "$post" "${labels[@]}"
    fi
    ;;
  results) results "${2:?usage: $0 results <act log>}" ;;
  *)
    echo "usage: $0 run|event <repo dir> [--pr <number>] [--post] [--label <name>]... | results <act log>" >&2
    exit 2
    ;;
esac
