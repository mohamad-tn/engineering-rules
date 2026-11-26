#!/usr/bin/env bash
# Lints every PHP file outside vendor/ with `php -l`. Prints each broken file.
set -uo pipefail
bad=0
while IFS= read -r -d '' f; do
  if ! out="$(php -l "$f" 2>&1)"; then
    printf '%s\n' "$out" | head -n 3
    bad=1
  fi
done < <(find . -name '*.php' -not -path './vendor/*' -not -path './node_modules/*' -not -path './storage/*' -print0)
exit "$bad"
