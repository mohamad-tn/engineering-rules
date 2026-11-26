#!/usr/bin/env bash
# Fails when `go mod tidy` would change go.mod or go.sum. Restores both files
# afterwards, so it never leaves the working tree modified.
set -euo pipefail
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
cp go.mod "$t/go.mod"
had_sum=0
if [[ -f go.sum ]]; then
  had_sum=1
  cp go.sum "$t/go.sum"
fi
go mod tidy >/dev/null 2>&1 || true
rc=0
cmp -s go.mod "$t/go.mod" || rc=1
if ((had_sum)); then
  cmp -s go.sum "$t/go.sum" || rc=1
elif [[ -f go.sum ]]; then
  rc=1
fi
cp "$t/go.mod" go.mod
if ((had_sum)); then cp "$t/go.sum" go.sum; else rm -f go.sum; fi
if ((rc != 0)); then
  echo "go.mod/go.sum are not tidy: run go mod tidy and commit the result"
  exit 1
fi
