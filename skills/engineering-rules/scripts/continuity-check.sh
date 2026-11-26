#!/usr/bin/env bash
# Delivery continuity check: is something your delivery workflow depends on
# degraded? Prints one "<check>\t<ok|warn|fail>\t<detail>" line per check and
# exits 1 when any check fails (warnings do not fail).
#
#   bash continuity-check.sh [--repos "<owner>/<repo> <owner>/<repo>"] [--skip-local]
#
# Built-in checks (all read public status pages or use your `gh` login; nothing
# reads or prints a secret):
#   - status pages in STATUS_PAGES (Atlassian Statuspage "summary.json" format);
#   - hosted CI jobs the forge refused to start in the last 24 hours (a sign of
#     exhausted minutes or a failed payment), via `gh`, when --repos is given;
#   - the CI_RUNNER variable of each repo vs. whether a self-hosted runner is online;
#   - local disk space.
# Add your own checks (hosting, registries, a database expiry, ...) as
# executable files in continuity-checks.d/ next to this script: each prints
# lines in the same "<check>\t<status>\t<detail>" format and exits non-zero on fail.
# Register every dependency in references/continuity.md.
#
# Env: STATUS_PAGES (newline-separated "name|url"; default: GitHub and npm),
#      BILLING_BLOCK_PATTERN (regex of the forge's "not started" annotation),
#      DISK_WARN_PCT (80), DISK_FAIL_PCT (90).
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
repos="" skip_local="false"
while (($#)); do
  case "$1" in
    --repos) repos="${2:?--repos needs a list}"; shift 2 ;;
    --skip-local) skip_local="true"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

default_pages=$'github|https://www.githubstatus.com/api/v2/summary.json\nnpm|https://status.npmjs.org/api/v2/summary.json'
status_pages="${STATUS_PAGES:-$default_pages}"
billing_block="${BILLING_BLOCK_PATTERN:-recent account payments have failed|spending limit needs to be increased}"
disk_warn="${DISK_WARN_PCT:-80}"
disk_fail="${DISK_FAIL_PCT:-90}"

failures=0
report() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  if [[ "$2" == "fail" ]]; then failures=$((failures + 1)); fi
}

fetch() { curl --fail --silent --show-error --max-time 10 "$1"; }

check_status_pages() {
  local entry name url body indicator degraded
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    name="${entry%%|*}"
    url="${entry#*|}"
    if ! body="$(fetch "$url" 2>/dev/null)"; then
      report "status:${name}" warn "status page unreachable (${url})"
      continue
    fi
    indicator="$(jq -r '.status.indicator' <<<"$body")"
    degraded="$(jq -r '[.components[]? | select(.status != "operational" and (.group_id == null)) | "\(.name)=\(.status)"] | join(", ")' <<<"$body")"
    case "$indicator" in
      none) report "status:${name}" ok "operational" ;;
      minor) report "status:${name}" warn "${degraded:-minor incident}" ;;
      *) report "status:${name}" fail "${indicator}: ${degraded:-see ${url%%/api/*}}" ;;
    esac
  done <<<"$status_pages"
}

# Hosted jobs the forge refused to start in the last 24 hours.
check_hosted_billing() {
  command -v gh >/dev/null 2>&1 || { report "ci:billing" warn "gh not installed, skipped"; return; }
  local since slug run_ids id job_ids job blocked=""
  since="$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)"
  for slug in $repos; do
    run_ids="$(gh api "repos/${slug}/actions/runs?status=failure&created=>=${since}&per_page=10" \
      --jq '.workflow_runs[].id' 2>/dev/null)" || { report "ci:${slug}" warn "runs API unavailable"; continue; }
    for id in $run_ids; do
      job_ids="$(gh api "repos/${slug}/actions/runs/${id}/jobs" \
        --jq '.jobs[] | select(.conclusion == "failure" and (.steps | length) == 0) | .id' 2>/dev/null)" || continue
      for job in $job_ids; do
        if gh api "repos/${slug}/check-runs/${job}/annotations" --jq '.[].message' 2>/dev/null | grep -Eq "$billing_block"; then
          blocked+="${slug} run ${id}; "
          break 2
        fi
      done
    done
  done
  if [[ -n "$blocked" ]]; then
    report "ci:billing" warn "hosted jobs not started (${blocked%; }): hosted minutes may be out; move to level 1 (see references/continuity.md)"
  else
    report "ci:billing" ok "no refused hosted job in 24 h"
  fi
}

check_runners() {
  command -v gh >/dev/null 2>&1 || return 0
  local slug value online
  for slug in $repos; do
    value="$(gh api "repos/${slug}/actions/variables/CI_RUNNER" --jq .value 2>/dev/null || echo "hosted")"
    online="$(gh api "repos/${slug}/actions/runners" --jq '[.runners[] | select(.status == "online")] | length' 2>/dev/null || echo "unknown")"
    if [[ "$value" == *self-hosted* && "$online" == "0" ]]; then
      report "runner:${slug}" fail "CI_RUNNER=${value} but no self-hosted runner is online"
    else
      report "runner:${slug}" ok "CI_RUNNER=${value}; online self-hosted runners: ${online}"
    fi
  done
}

check_local() {
  local used
  used="$(df --output=pcent / | tail -n 1 | tr -dc '0-9')"
  if ((used >= disk_fail)); then
    report "local:disk" fail "/ is ${used}% full"
  elif ((used >= disk_warn)); then
    report "local:disk" warn "/ is ${used}% full"
  else
    report "local:disk" ok "/ is ${used}% full"
  fi
}

run_plugins() {
  local plugin out status
  [[ -d "${here}/continuity-checks.d" ]] || return 0
  for plugin in "${here}"/continuity-checks.d/*; do
    [[ -x "$plugin" ]] || continue
    status=0
    out="$("$plugin" 2>&1)" || status=$?
    printf '%s\n' "$out"
    if ((status != 0)); then failures=$((failures + 1)); fi
  done
}

check_status_pages
if [[ -n "$repos" ]]; then
  check_hosted_billing
  check_runners
fi
[[ "$skip_local" == "true" ]] || check_local
run_plugins
((failures == 0))
