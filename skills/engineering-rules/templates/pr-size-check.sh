#!/usr/bin/env bash
# Pull-request size gate.
# Counts added + deleted lines in the three-dot diff (base...head). Paths in
# the exclusion list (lockfiles, snapshots, generated code) are not counted:
# they move in large mechanical chunks and would hide the real review size.
#
# CI passes BASE_SHA, HEAD_SHA and PR_LABELS_JSON. Locally, with no variables,
# it compares HEAD with its merge-base against origin/<DEFAULT_BRANCH>.
#
# Env: WARN_LINES (400), FAIL_LINES (800), REASON_LABEL (pr-size-reason),
#      DEFAULT_BRANCH (main), PR_SIZE_EXCLUDE_FILE (default: pr-size-exclude.txt
#      next to this script), PR_LABELS_JSON (JSON array of label names).
set -euo pipefail

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

# Profile (thresholds) from .github/engineering-rules.env, if the repository has one.
profile="${ENGINEERING_RULES_ENV:-.github/engineering-rules.env}"
er_load_env "$profile"

# "Above" is strict: exactly WARN_LINES warns nothing, WARN_LINES+1 warns.
WARN_LINES="${WARN_LINES:-400}"
FAIL_LINES="${FAIL_LINES:-800}"
REASON_LABEL="${REASON_LABEL:-pr-size-reason}"
if [[ -z "${DEFAULT_BRANCH:-}" ]]; then
  DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [[ -z "$DEFAULT_BRANCH" ]]; then
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then DEFAULT_BRANCH=main
    elif git rev-parse --verify -q origin/master >/dev/null 2>&1; then DEFAULT_BRANCH=master
    else DEFAULT_BRANCH=main; fi
  fi
fi

die() {
  echo "::error::$*" >&2
  exit 1
}

validate_sha() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9a-fA-F]{40}$ ]]; then
    die "${name} must be a 40-character hexadecimal commit SHA"
  fi
}

exclude_file() {
  if [[ -n "${PR_SIZE_EXCLUDE_FILE:-}" ]]; then
    printf '%s\n' "$PR_SIZE_EXCLUDE_FILE"
    return
  fi
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${dir}/pr-size-exclude.txt"
}

# Returns 0 when the path matches an exclusion pattern.
path_excluded() {
  local path="$1"
  local pattern dir base
  base="$(basename "$path")"
  while IFS= read -r pattern || [[ -n "${pattern:-}" ]]; do
    pattern="${pattern%$'\r'}"
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    if [[ "$pattern" == */ ]]; then
      dir="${pattern%/}"
      case "$path" in
        "${dir}"/* | */"${dir}"/*) return 0 ;;
      esac
    elif [[ "$pattern" == */* ]]; then
      # Patterns are globs (*.snap): they must stay unquoted to match.
      # shellcheck disable=SC2254
      case "$path" in
        $pattern | */$pattern) return 0 ;;
      esac
    else
      # shellcheck disable=SC2254
      case "$base" in
        $pattern) return 0 ;;
      esac
    fi
  done <"$(exclude_file)"
  return 1
}

# Prints "<included> <excluded>".
count_lines() {
  local base="$1"
  local head="$2"
  local added deleted path included=0 excluded=0
  while IFS=$'\t' read -r added deleted path; do
    [[ -z "${path:-}" ]] && continue
    # Binary files have no line count.
    if [[ "$added" == "-" || "$deleted" == "-" ]]; then
      continue
    fi
    local check="$path"
    # Renames print "old => new" or "dir/{old => new}/file".
    if [[ "$path" == *" => "* ]]; then
      check="$(printf '%s' "$path" | sed -E 's/\{[^{}]* => ([^{}]*)\}/\1/; s#//+#/#g; s/^.* => //')"
    fi
    local delta=$((added + deleted))
    if path_excluded "$check"; then
      excluded=$((excluded + delta))
    else
      included=$((included + delta))
    fi
  done < <(git diff --numstat -M "${base}...${head}")
  printf '%s %s\n' "$included" "$excluded"
}

has_reason_label() {
  local labels="${PR_LABELS_JSON:-[]}"
  if [[ -z "$labels" || "$labels" == "null" ]]; then
    labels="[]"
  fi
  jq -e --arg name "$REASON_LABEL" 'type == "array" and index($name) != null' <<<"$labels" >/dev/null
}

write_summary() {
  local included="$1" excluded="$2" status="$3"
  local summary="${GITHUB_STEP_SUMMARY:-}"
  [[ -z "$summary" ]] && return 0
  cat >>"$summary" <<SUMMARY
### PR size

| | |
|---|---|
| Counted lines | ${included} |
| Excluded lines | ${excluded} |
| Warn above | ${WARN_LINES} |
| Fail above | ${FAIL_LINES} |
| Result | ${status} |

A pull request above ${FAIL_LINES} lines needs the label \`${REASON_LABEL}\` and a written reason in its body.
SUMMARY
}

main() {
  local base="${BASE_SHA:-}" head="${HEAD_SHA:-}"
  if [[ -z "$base" ]]; then
    base="$(git merge-base "origin/${DEFAULT_BRANCH}" HEAD 2>/dev/null)" ||
      die "BASE_SHA is not set and origin/${DEFAULT_BRANCH} was not found"
  fi
  [[ -z "$head" ]] && head="$(git rev-parse HEAD)"
  validate_sha "BASE_SHA" "$base"
  validate_sha "HEAD_SHA" "$head"
  [[ -f "$(exclude_file)" ]] || die "Exclusion list not found: $(exclude_file)"
  git cat-file -e "${base}^{commit}" 2>/dev/null || die "BASE_SHA is not in this clone"
  git cat-file -e "${head}^{commit}" 2>/dev/null || die "HEAD_SHA is not in this clone"

  local included excluded
  read -r included excluded < <(count_lines "$base" "$head")

  local status="ok"
  if ((included > FAIL_LINES)); then
    if has_reason_label; then status="exception"; else status="fail"; fi
  elif ((included > WARN_LINES)); then
    status="warn"
  fi

  write_summary "$included" "$excluded" "$status"
  echo "PR size: ${included} counted lines, ${excluded} excluded (warn above ${WARN_LINES}, fail above ${FAIL_LINES})."

  case "$status" in
    ok) ;;
    warn)
      echo "::warning::This pull request changes ${included} lines, above ${WARN_LINES}. Split it if you can."
      ;;
    exception)
      echo "::warning::This pull request changes ${included} lines, above ${FAIL_LINES}. The label ${REASON_LABEL} is present, so the check does not fail. The reason must be in the pull request body."
      ;;
    fail)
      echo "::error::This pull request changes ${included} lines, above ${FAIL_LINES}. Split it, or add the label ${REASON_LABEL} with a written reason."
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
