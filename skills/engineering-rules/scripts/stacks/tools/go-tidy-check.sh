#!/usr/bin/env bash
# Fails when `go mod tidy` fails or would change go.mod/go.sum. Always restores
# the original files so checking never leaves a modified dependency lock.
set -euo pipefail
t="$(mktemp -d)"
cp go.mod "$t/go.mod"
had_sum=0
if [[ -f go.sum ]]; then
  had_sum=1
  cp go.sum "$t/go.sum"
fi
cleanup() {
  cp "$t/go.mod" go.mod
  if ((had_sum)); then cp "$t/go.sum" go.sum; else rm -f go.sum; fi
  rm -rf "$t"
}
trap cleanup EXIT
status=0
go mod tidy >"$t/tidy.log" 2>&1 || status=$?
if ((status != 0)); then
  echo "go mod tidy could not complete (exit ${status})."
  tail -n 25 "$t/tidy.log"
  exit "$status"
fi
rc=0
cmp -s go.mod "$t/go.mod" || rc=1
if ((had_sum)); then
  cmp -s go.sum "$t/go.sum" || rc=1
elif [[ -f go.sum ]]; then
  rc=1
fi
if ((rc != 0)); then
  echo "go.mod/go.sum are not tidy: run go mod tidy and commit the result"
  exit 1
fi
