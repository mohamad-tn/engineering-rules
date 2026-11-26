#!/usr/bin/env bash
# Fails when `dotnet list package --vulnerable` reports a vulnerable package.
# It passes ONLY when the tool says the project has no vulnerable packages; any
# other output (no assets file, no network) is "undetermined", never a pass.
# Usage: dotnet-vuln-check.sh <solution or project>
set -uo pipefail
target="${1:?usage: dotnet-vuln-check.sh <solution or project>}"
out="$(dotnet list "$target" package --vulnerable --include-transitive 2>&1)"
printf '%s\n' "$out" | tail -n 25
if grep -q 'has the following vulnerable packages' <<<"$out"; then
  echo "Vulnerable packages found."
  exit 1
fi
if grep -qE 'has no vulnerable packages|no vulnerable packages' <<<"$out"; then
  exit 0
fi
if grep -qiE 'Unable to load the service index|Name or service not known|NU1301' <<<"$out"; then
  echo "Unable to load the service index (network unavailable)"
  exit 1
fi
echo "Could not determine vulnerability status (run a restore first)."
exit 1
