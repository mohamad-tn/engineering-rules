#!/usr/bin/env bash
# Multi-repository setups only. One repository OWNS the rules file
# (AGENTS.md); every other repository carries a byte-identical copy that is
# never edited in place. This script, run from a clone of the owner
# repository, opens one pull request per target with the new copy.
# It never merges anything.
#
#   RULES_SYNC_TARGETS="<org>/backend <org>/web <org>/mobile" \
#     bash sync-rules-file.sh [--file AGENTS.md] [--dry-run]
#
# Safety: the target list comes only from the environment (an allowlist), the
# working branch name is fixed, and the target's default branch is never pushed
# to. Needs `git` and `gh` logged in with rights to open pull requests on the
# targets. Run it from CI with a token scoped to those repositories only.
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

file="AGENTS.md" dry="false"
branch="sync/rules-file"
while (($#)); do
  case "$1" in
    --file) file="${2:?--file needs a path}"; shift 2 ;;
    --dry-run) dry="true"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

: "${RULES_SYNC_TARGETS:?set RULES_SYNC_TARGETS to the allowlist of <org>/<repo> targets}"
[[ -f "$file" ]] || { echo "${file} not found in $(pwd)" >&2; exit 1; }
self="$(git remote get-url origin | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failed=0

for target in $RULES_SYNC_TARGETS; do
  if [[ "$target" == "$self" ]]; then
    echo "skip ${target}: it is the owner repository"
    continue
  fi
  echo "== ${target}"
  if [[ "$dry" == "true" ]]; then
    echo "dry run: would open a pull request that makes ${file} identical"
    continue
  fi
  if ! gh repo clone "$target" "${work}/${target##*/}" -- --quiet; then
    echo "::error::cannot clone ${target}" >&2
    failed=1
    continue
  fi
  (
    cd "${work}/${target##*/}"
    default="$(git rev-parse --abbrev-ref HEAD)"
    if cmp --silent "${OLDPWD}/${file}" "$file" 2>/dev/null; then
      echo "already identical"
      exit 0
    fi
    git checkout -q -B "$branch"
    cp "${OLDPWD}/${file}" "$file"
    git add "$file"
    git commit -q -m "chore: sync ${file} from ${self}"
    git push -q --force-with-lease origin "$branch"
    gh pr create --base "$default" --head "$branch" \
      --title "chore: sync ${file} from ${self}" \
      --body "Automated copy of the canonical rules file. Do not edit it here; change it in ${self}." ||
      gh pr edit "$branch" --body "Automated copy of the canonical rules file. Do not edit it here; change it in ${self}."
  ) || failed=1
done
exit "$failed"
