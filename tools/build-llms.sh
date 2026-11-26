#!/usr/bin/env bash
# Builds llms-full.txt: the essential content in ONE plain file (rules, skill entry, rule index, stack list)
# for agents and answer engines that fetch a single URL. llms.txt is the hand-written index.
#   bash tools/build-llms.sh            # write llms-full.txt
#   bash tools/build-llms.sh --check    # exit 1 if llms-full.txt is out of date
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
s="${root}/skills/engineering-rules"
owner="mohamad-tn" repo="engineering-rules"
if [[ -f "${root}/tools/publish.json" ]]; then
  owner="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["owner"])' "${root}/tools/publish.json")"
  repo="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["repo"])' "${root}/tools/publish.json")"
fi
out="$(mktemp)"
{
  echo "# engineering-rules (full text for agents)"
  echo
  echo "Source: https://github.com/${owner}/${repo}"
  for f in "${s}/SKILL.md" "${s}/templates/AGENTS.md" "${s}/references/rules-index.md" "${s}/references/stacks/README.md" "${s}/references/fixing-failures.md"; do
    echo
    echo "---"
    echo "## FILE: ${f#"${root}"/}"
    echo
    cat "$f"
  done
} >"$out"
if [[ "${1:-}" == "--check" ]]; then
  cmp -s "$out" "${root}/llms-full.txt" || { echo "llms-full.txt is out of date: run bash tools/build-llms.sh" >&2; rm -f "$out"; exit 1; }
  rm -f "$out"
  echo "llms-full.txt is current"
else
  mv "$out" "${root}/llms-full.txt"
  echo "wrote llms-full.txt ($(wc -c <"${root}/llms-full.txt") bytes)"
fi
