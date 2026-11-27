#!/usr/bin/env bash
# Fill repository-level placeholders and refresh tools/publish.json before publishing.
# Usage: bash tools/publish-prep.sh --owner <user-or-org> [--repo <name>]
#        [--author <name>] [--year YYYY] [--dry-run]
# Does not touch placeholders intended for projects adopting this skill.
set -euo pipefail

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
    --owner) (($# >= 2)) || { echo "--owner requires a value" >&2; exit 2; }; owner="$2"; shift 2 ;;
    --repo) (($# >= 2)) || { echo "--repo requires a value" >&2; exit 2; }; repo="$2"; shift 2 ;;
    --author) (($# >= 2)) || { echo "--author requires a value" >&2; exit 2; }; author="$2"; shift 2 ;;
    --year) (($# >= 2)) || { echo "--year requires a value" >&2; exit 2; }; year="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# *//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$root" "$owner" "$repo" "$author" "$year" "$dry" <<'PY'
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
owner, repo, author, year, dry = sys.argv[2:]
if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?", owner, re.ASCII):
    raise SystemExit("invalid GitHub owner: use 1-39 ASCII letters, digits or internal hyphens")
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,99}", repo, re.ASCII):
    raise SystemExit("invalid GitHub repository name: use at most 100 ASCII letters, digits, '.', '_' or '-'")
if not re.fullmatch(r"[1-9][0-9]{3}", year, re.ASCII):
    raise SystemExit("year must be a four-digit year from 1000 through 9999")
if not author:
    author = owner
if any(ord(char) < 32 or 0x7f <= ord(char) <= 0x9f for char in author):
    raise SystemExit("author must not contain control characters")

replacements = {
    b"__GH_OWNER__": owner.encode("utf-8"),
    b"__GH_REPO__": repo.encode("utf-8"),
    b"__AUTHOR__": author.encode("utf-8"),
    b"__YEAR__": year.encode("ascii"),
}
excluded = {".git", "node_modules", "tests", ".venv"}
changes = []
for directory, dirs, files in os.walk(root, topdown=True, followlinks=False):
    dirs[:] = sorted(d for d in dirs if d not in excluded and not os.path.islink(os.path.join(directory, d)))
    for name in sorted(files):
        path = Path(directory) / name
        if path.name == "publish-prep.sh" or path.is_symlink():
            continue
        original = path.read_bytes()
        if not any(token in original for token in replacements):
            continue
        try:
            original.decode("utf-8")
        except UnicodeDecodeError as error:
            raise SystemExit(f"refusing non-UTF-8 placeholder file: {path.relative_to(root)}") from error
        updated = original
        for token, value in replacements.items():
            updated = updated.replace(token, value)
        if updated != original:
            changes.append((path, updated))

metadata = root / "tools/publish.json"
metadata_bytes = (json.dumps({"owner": owner, "repo": repo, "author": author}, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
metadata_changed = not metadata.is_file() or metadata.read_bytes() != metadata_bytes
if dry == "1":
    for path, _ in changes:
        print(f"would update {path.relative_to(root)}")
    if metadata_changed:
        print("would update tools/publish.json")
    print(f"dry-run complete: {len(changes)} placeholder file(s), metadata={'changed' if metadata_changed else 'current'}")
    raise SystemExit(0)

# Prepare all replacement files before the first rename so an encoding or disk
# error during preparation cannot leave only part of the repository rewritten.
staged = []
try:
    for path, content in changes:
        mode = stat.S_IMODE(path.stat(follow_symlinks=False).st_mode)
        fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
        temporary = Path(tmp_name)
        staged.append((temporary, path))
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp_name, mode)
    metadata.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=".publish.json.", dir=metadata.parent)
    temporary = Path(tmp_name)
    staged.append((temporary, metadata))
    with os.fdopen(fd, "wb") as stream:
        stream.write(metadata_bytes)
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(tmp_name, 0o644)
    for temporary, destination in staged:
        os.replace(temporary, destination)
except OSError as error:
    for temporary, _ in staged:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass
    raise SystemExit(f"could not update publish files: {error}") from error

for path, _ in changes:
    print(f"updated {path.relative_to(root)}")
if metadata_changed:
    print("updated tools/publish.json")
print("Done. Review 'git diff', then commit.")
PY
