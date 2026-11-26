#!/usr/bin/env bash
# Fills the repository-level placeholders before you publish on GitHub.
#
#   bash tools/publish-prep.sh --owner <github user or org> [--repo <name>] \
#                              [--author "<Full name or org>"] [--year 2026] [--dry-run]
#
# Records your values in tools/publish.json (read by the site and llms generators, so their
# --check stays green) and replaces __GH_OWNER__, __GH_REPO__, __AUTHOR__ and __YEAR__ in the repository's own
# files (README, LICENSE, issue templates, docs). It does NOT touch the skill's
# <owner>, <org> and <project> placeholders: those are for projects that adopt the skill.
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

owner="" repo="engineering-rules-skill" author="" year="$(date +%Y)" dry=0
while (($#)); do
  case "$1" in
    --owner) owner="${2:?}"; shift 2 ;;
    --repo) repo="${2:?}"; shift 2 ;;
    --author) author="${2:?}"; shift 2 ;;
    --year) year="${2:?}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h | --help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$owner" ]] || { echo "--owner is required" >&2; exit 2; }
[[ "$owner" =~ ^[A-Za-z0-9-]+$ && "$repo" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "owner and repo may contain letters, digits, '-', '.', '_' only" >&2; exit 2; }
[[ -n "$author" ]] || author="$owner"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
files=()
while IFS= read -r _f; do files+=("$_f"); done < <(grep -rlE '__GH_OWNER__|__GH_REPO__|__AUTHOR__|__YEAR__' "$root" \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=tests --exclude=publish-prep.sh 2>/dev/null || true)

if ((${#files[@]} == 0)); then
  echo "No placeholders found: already prepared."
  exit 0
fi
for f in "${files[@]}"; do
  if ((dry)); then echo "would update ${f#"$root"/}"; continue; fi
  echo "updated ${f#"$root"/}"
  sed -i.bak -e "s#__GH_OWNER__#${owner}#g" -e "s#__GH_REPO__#${repo}#g" -e "s#__AUTHOR__#${author//#/\\#}#g" -e "s#__YEAR__#${year}#g" "$f" && rm -f "${f}.bak"
done
if ((! dry)); then
  printf '{\n  "owner": "%s",\n  "repo": "%s",\n  "author": "%s"\n}\n' "$owner" "$repo" "${author//\"/}" >"${root}/tools/publish.json"
fi
((dry)) || echo "Done. Review 'git diff', then commit."
