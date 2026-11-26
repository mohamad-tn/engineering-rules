#!/usr/bin/env bash
# Copies every NON-translated file (scripts, configs, workflows, JSON) from the English
# skill into the Arabic skill so the two editions never drift. Markdown (.md, .mdc) is
# translated by hand; tests/test-parity.sh fails when a translation is missing.
#   bash tools/sync-ar.sh
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
en="${root}/skills/engineering-rules"
ar="${root}/skills/engineering-rules-ar"
count=0
while IFS= read -r f; do
  rel="${f#"$en"/}"
  mkdir -p "$(dirname "${ar}/${rel}")"
  if ! cmp -s "$f" "${ar}/${rel}" 2>/dev/null; then
    cp -p "$f" "${ar}/${rel}"
    count=$((count + 1))
  fi
done < <(find "$en" -type f -not -name '*.md' -not -name '*.mdc')
# remove non-translated files that no longer exist in English
while IFS= read -r f; do
  rel="${f#"$ar"/}"
  [[ -e "${en}/${rel}" ]] || { rm -f "$f"; count=$((count + 1)); }
done < <(find "$ar" -type f -not -name '*.md' -not -name '*.mdc')
echo "synced ${count} file(s)"
