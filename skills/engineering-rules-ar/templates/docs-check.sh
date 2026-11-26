#!/usr/bin/env bash
# docs-check: required docs + docs map + changelog rule, markdown lint,
# and an offline check of internal links and anchors.
# Usage: docs-check.sh [repo dir]   (default: current directory)
#
# Pull-request context (optional): BASE_SHA, HEAD_SHA, PR_LABELS_JSON, PR_TITLE.
# Tools are pinned in .github/tool-pins.env:
#   MARKDOWNLINT_CLI2_VERSION   (run through npx unless already installed)
#   LYCHEE_VERSION, LYCHEE_SHA256 (or lychee already on PATH)
# Other env: DOCS_LINT_SCOPE (changed | all), DOCS_LINT_CONFIG, DOCS_LINT_IGNORE (space-separated globs that are
# neither linted nor link-checked, for example files copied from another repo).
# SKIP_MD_LINT=1 / SKIP_LINK_CHECK=1 exist for debugging only and print a
# warning; a skipped check is not proof, so never set them in CI.
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

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${1:-.}" && pwd)"
pins="${TOOL_PINS_FILE:-${repo}/.github/tool-pins.env}"
er_load_env "$pins"
profile="${ENGINEERING_RULES_ENV:-${repo}/.github/engineering-rules.env}"
er_load_env "$profile"
# docs-check.mjs sits next to this script. ensure-tool.sh is found next to it
# too (after copying both into .github/scripts/) or in ../scripts/ (this package).
mjs="${DOCS_CHECK_MJS:-${here}/docs-check.mjs}"
ensure_tool="${here}/ensure-tool.sh"
[[ -f "$ensure_tool" ]] || ensure_tool="${here}/../scripts/ensure-tool.sh"
status=0

echo "== required docs, docs map, changelog"
node "$mjs" "$repo" || status=1

# Which markdown files are linted and link-checked:
#   DOCS_LINT_SCOPE=changed (default)  only files changed in this pull request (or in
#                                      the last commit when there is no pull-request
#                                      context), so an existing repository with old,
#                                      messy docs can adopt the gates without a cleanup
#   DOCS_LINT_SCOPE=all                every markdown file (profile strict)
scope="${DOCS_LINT_SCOPE:-changed}"
md_targets=("**/*.md")
if [[ "$scope" == "changed" ]]; then
  range=""
  if [[ -n "${BASE_SHA:-}" && -n "${HEAD_SHA:-}" ]]; then range="${BASE_SHA}...${HEAD_SHA}"
  elif git -C "$repo" rev-parse --verify -q HEAD~1 >/dev/null 2>&1; then range="HEAD~1...HEAD"; fi
  if [[ -n "$range" ]]; then
    md_targets=()
    while IFS= read -r _f; do
      [[ -f "${repo}/${_f}" ]] && md_targets+=("$_f")
    done < <(git -C "$repo" diff --name-only --diff-filter=ACMR "$range" -- '*.md' 2>/dev/null)
  fi
fi

lint_config="${DOCS_LINT_CONFIG:-${repo}/.github/docs-check/.markdownlint.jsonc}"
ignore_globs=()
for glob in ${DOCS_LINT_IGNORE:-}; do ignore_globs+=("#${glob}"); done

echo "== markdown lint"
if [[ "${SKIP_MD_LINT:-0}" == "1" ]]; then
  echo "::warning::markdown lint SKIPPED (SKIP_MD_LINT=1). This is not proof."
elif ((${#md_targets[@]} == 0)); then
  echo "no markdown files changed (scope: ${scope}): nothing to lint"
else
  if [[ -x "${repo}/node_modules/.bin/markdownlint-cli2" ]]; then
    lint=("${repo}/node_modules/.bin/markdownlint-cli2")
  elif command -v markdownlint-cli2 >/dev/null 2>&1; then
    lint=(markdownlint-cli2)
  elif [[ -n "${MARKDOWNLINT_CLI2_VERSION:-}" ]]; then
    lint=(npx --yes "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}")
  else
    echo "::error::markdownlint-cli2 is not installed and MARKDOWNLINT_CLI2_VERSION is not pinned in .github/tool-pins.env" >&2
    lint=()
    status=1
  fi
  if ((${#lint[@]} > 0)); then
    config_args=()
    [[ -f "$lint_config" ]] && config_args=(--config "$lint_config")
    if [[ "$scope" == "changed" ]]; then
      (cd "$repo" && "${lint[@]}" "${config_args[@]}" "${md_targets[@]}") || status=1
    else
      (cd "$repo" && "${lint[@]}" "${config_args[@]}" "**/*.md" "#**/node_modules/**" "${ignore_globs[@]}") || status=1
    fi
  fi
fi

# Offline: internal files and anchors only. External URLs are not fetched,
# so a third-party outage never blocks a merge.
echo "== internal links and anchors"
if [[ "${SKIP_LINK_CHECK:-0}" == "1" ]]; then
  echo "::warning::link check SKIPPED (SKIP_LINK_CHECK=1). This is not proof."
elif ((${#md_targets[@]} == 0)); then
  echo "no markdown files changed (scope: ${scope}): no links to check"
elif lychee_bin="$(bash "$ensure_tool" lychee)"; then
  exclude_args=(--exclude-path node_modules)
  for glob in ${DOCS_LINT_IGNORE:-}; do exclude_args+=(--exclude-path "$glob"); done
  if [[ "$scope" == "changed" ]]; then
    (cd "$repo" && "$lychee_bin" --offline --include-fragments --no-progress --format compact "${exclude_args[@]}" "${md_targets[@]}") || status=1
  else
    (cd "$repo" && "$lychee_bin" --offline --include-fragments --no-progress --format compact "${exclude_args[@]}" "**/*.md") || status=1
  fi
else
  echo "::error::lychee is not available (install it or pin LYCHEE_VERSION and LYCHEE_SHA256 in .github/tool-pins.env)" >&2
  status=1
fi

if [[ "$status" -ne 0 ]]; then
  echo "docs-check failed."
fi
exit "$status"
