#!/usr/bin/env bash
# shellcheck shell=bash
# Sourced by the gate scripts. Loads KEY=VALUE lines from a file WITHOUT overriding
# variables that are already set in the environment, so an explicit
#   DOCS_LINT_SCOPE=all bash .github/scripts/docs-check.sh
# always beats the profile file (.github/engineering-rules.env) and the tool pins.
er_load_env() {
  local file="$1" line key val
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in '' | '#'* | ' '*) continue ;; esac
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"
    if [[ -z "${!key+x}" ]]; then export "$key=$val"; fi
  done <"$file"
}
