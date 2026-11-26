#!/usr/bin/env bash
# Fails when dotnet reports a vulnerability or cannot finish the entire check.
# A success sentence from one project is not evidence for a failed solution scan.
# Usage: dotnet-vuln-check.sh <solution or project>
set -uo pipefail
target="${1:?usage: dotnet-vuln-check.sh <solution or project>}"
status=0
out="$(dotnet list "$target" package --vulnerable --include-transitive 2>&1)" || status=$?
printf '%s\n' "$out" | tail -n 25
if ((status != 0)); then
  echo "Could not determine vulnerability status (dotnet exited ${status})."
  exit 1
fi
if grep -q 'has the following vulnerable packages' <<<"$out"; then
  echo "Vulnerable packages found."
  exit 1
fi
if grep -qiE 'Unable to load the service index|Name or service not known|NU1301' <<<"$out"; then
  echo "Unable to load the service index (network unavailable)"
  exit 1
fi
if grep -qE 'has no vulnerable packages|no vulnerable packages' <<<"$out"; then
  exit 0
fi
echo "Could not determine vulnerability status (run a restore first)."
exit 1
