#!/usr/bin/env bash
# Synchronize non-translated skill files from English to Arabic.
# Markdown and .mdc rules are translated separately and are never overwritten.
# Usage: bash tools/sync-ar.sh [--check|--dry-run]
set -euo pipefail

if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

mode=sync
while (($#)); do
  case "$1" in
    --check) [[ "$mode" == sync ]] || { echo "choose only one of --check or --dry-run" >&2; exit 2; }; mode=check; shift ;;
    --dry-run) [[ "$mode" == sync ]] || { echo "choose only one of --check or --dry-run" >&2; exit 2; }; mode=dry-run; shift ;;
    -h|--help) sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# *//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
en="${root}/skills/engineering-rules"
ar="${root}/skills/engineering-rules-ar"
for required in "$en" "$ar"; do
  [[ -d "$required" && ! -L "$required" ]] || { echo "required skill directory is missing or unsafe: ${required#"$root"/}" >&2; exit 1; }
done
for required in "$en/SKILL.md" "$ar/SKILL.md"; do
  [[ -f "$required" && ! -L "$required" ]] || { echo "required skill entry is missing or unsafe: ${required#"$root"/}" >&2; exit 1; }
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/engineering-rules-sync.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
# Refuse symlinks rather than silently skipping a source or target entry.
if ! find "$en" "$ar" -type l -print0 >"$tmp/symlinks.list"; then
  echo "could not inspect skill symlinks" >&2
  exit 1
fi
if [[ -s "$tmp/symlinks.list" ]]; then
  echo "symlinks in skill trees are not supported by sync-ar" >&2
  exit 1
fi

mkdir -p "$tmp/stage"
if ! find "$en" -type f -not -name '*.md' -not -name '*.mdc' -print0 >"$tmp/source.list"; then
  echo "could not enumerate English skill files" >&2
  exit 1
fi
if ! find "$ar" -type f -not -name '*.md' -not -name '*.mdc' -print0 >"$tmp/target.list"; then
  echo "could not enumerate Arabic skill files" >&2
  exit 1
fi

# Stage every source before modifying the destination or deleting stale files.
while IFS= read -r -d '' f; do
  rel="${f#"$en"/}"
  mkdir -p "$tmp/stage/$(dirname "$rel")"
  cp -p "$f" "$tmp/stage/$rel"
done <"$tmp/source.list"

changed=0
stale=0
if ! find "$tmp/stage" -type f -print0 >"$tmp/stage.list"; then
  echo "could not enumerate staged English skill files" >&2
  exit 1
fi
while IFS= read -r -d '' f; do
  rel="${f#"$tmp/stage"/}"
  if ! cmp -s "$f" "$ar/$rel"; then
    changed=$((changed + 1))
    case "$mode" in
      check) echo "out of sync: skills/engineering-rules-ar/$rel" ;;
      dry-run) echo "would copy: skills/engineering-rules-ar/$rel" ;;
      sync) mkdir -p "$(dirname "$ar/$rel")"; cp -p "$f" "$ar/$rel" ;;
    esac
  fi
done <"$tmp/stage.list"

while IFS= read -r -d '' f; do
  rel="${f#"$ar"/}"
  if [[ ! -f "$tmp/stage/$rel" ]]; then
    stale=$((stale + 1))
    case "$mode" in
      check) echo "stale: skills/engineering-rules-ar/$rel" ;;
      dry-run) echo "would remove: skills/engineering-rules-ar/$rel" ;;
      sync) rm -f -- "$f" ;;
    esac
  fi
done <"$tmp/target.list"

if [[ "$mode" == check && ( "$changed" -gt 0 || "$stale" -gt 0 ) ]]; then
  echo "Arabic non-translated files are out of sync (changed=$changed stale=$stale)" >&2
  exit 1
fi
if [[ "$mode" == sync ]]; then
  echo "synced $((changed + stale)) file(s)"
else
  echo "$mode complete: changed=$changed stale=$stale"
fi
