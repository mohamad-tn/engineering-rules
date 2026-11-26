#!/usr/bin/env bash
# The Arabic edition must mirror the English one: same files, same scripts (byte
# for byte), same sections, tables and code blocks. Only prose is translated.
# shellcheck disable=SC2181
set -uo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "== arabic edition parity"
python3 - "$REPO_ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
en, ar = root / "skills/engineering-rules", root / "skills/engineering-rules-ar"
problems, checks = [], 0

def files(base):
    return sorted(str(p.relative_to(base)) for p in base.rglob("*") if p.is_file())

def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        problems.append(msg)

fe, fa = files(en), files(ar)
check(fe == fa, f"file lists differ: only-en={sorted(set(fe)-set(fa))[:5]} only-ar={sorted(set(fa)-set(fe))[:5]}")

# Translated, tool-facing prose files: everything else must be byte-identical.
TEXT = (".md", ".mdc")
for f in fe:
    if f.endswith(TEXT) or f not in fa:
        continue
    check((en / f).read_bytes() == (ar / f).read_bytes(), f"not identical: {f}")

def blocks(t):
    return re.findall(r"^```[a-z]*\n(.*?)^```", t, re.S | re.M)

def stats(t):
    t = re.sub(r"<!-- rtl -->|</?div[^>]*>", "", t)
    return dict(h2=len(re.findall(r"^## ", t, re.M)), h3=len(re.findall(r"^### ", t, re.M)),
                rows=len(re.findall(r"^\|", t, re.M)), boxes=len(re.findall(r"^- \[ \]", t, re.M)),
                blocks=len(blocks(t)))

# code blocks that hold translated text (not code) are allowed to differ
ALLOWED = {"templates/PULL_REQUEST_TEMPLATE.md"}
pairs = [(en / f, ar / f, f) for f in fe if f.endswith(".md") and f in fa]
pairs += [(root / "README.md", root / "README.ar.md", "README")]
pairs += [(root / "docs" / p.name, p, f"docs/{p.name}") for p in sorted((root / "docs/ar").glob("*.md"))]
for e, a, name in pairs:
    if not e.exists():
        problems.append(f"no English counterpart for {name}")
        continue
    te, ta = e.read_text(encoding="utf-8"), a.read_text(encoding="utf-8")
    se, sa = stats(te), stats(ta)
    if name.endswith("rules-index.md"):
        pass
    check(se == sa, f"structure differs in {name}: en={se} ar={sa}")
    if name not in ALLOWED and name not in ("SKILL.md",) and name != "templates/agents/CLAUDE.md":
        # a mermaid diagram carries translated labels; every other code block must be identical
        be = [b for b in blocks(te) if not b.lstrip().startswith("flowchart")]
        # the Arabic edition lives in skills/engineering-rules-ar: normalise that path
        ba = [b.replace("engineering-rules-ar", "engineering-rules") for b in blocks(ta) if not b.lstrip().startswith("flowchart")]
        diff = [i for i, (x, y) in enumerate(zip(be, ba)) if x.strip() != y.strip()]
        check(not diff, f"code blocks differ in {name}: {diff}")
    if not name.startswith("templates/agents/") and name != "templates/CHANGELOG.md" and not name.endswith("/CHANGELOG.md"):
        check("<!-- rtl -->" in ta, f"missing RTL wrapper: {name}")

# the English docs must all exist in Arabic
for p in sorted((root / "docs").glob("*.md")):
    check((root / "docs/ar" / p.name).exists(), f"missing Arabic doc: docs/ar/{p.name}")
# frontmatter names
check(re.search(r"^name: engineering-rules$", (en / "SKILL.md").read_text(), re.M) is not None, "English SKILL name")
check(re.search(r"^name: engineering-rules-ar$", (ar / "SKILL.md").read_text(encoding="utf-8"), re.M) is not None, "Arabic SKILL name")
for pr in problems:
    print("  FAIL ", pr)
print(f"  {'FAIL' if problems else 'PASS'}  parity: {checks} checks, {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
PY
if [[ $? -eq 0 ]]; then ok "english and arabic editions mirror each other"; else bad "parity"; fi
summary
