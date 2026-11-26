#!/usr/bin/env bash
# Context budget and rule completeness. An agent has a limited context window: the
# files it loads every time must be small, and the always-loaded rules file must still
# state EVERY binding rule. Token counts are estimates (no tokenizer needed): English
# text about 3.6 characters per token, Arabic letters about 2.0.
set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "== context budget and rule completeness"
python3 - "$REPO_ROOT" <<'PY'
import json, pathlib, re, sys
import yaml
root = pathlib.Path(sys.argv[1])
bad = []
checks = 0

def tokens(text):
    ar = len(re.findall(r"[\u0600-\u06FF]", text))
    return int((len(text) - ar) / 3.6 + ar / 2.0)

def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        bad.append(msg)

editions = {"en": root / "skills/engineering-rules", "ar": root / "skills/engineering-rules-ar"}
# (max lines, max estimated tokens) per kind of file
SKILL_MAX = (120, 3000)        # loaded whenever the skill triggers; the Agent Skills guidance is under 500 lines / 5000 tokens
AGENTS_MAX = (110, 2800)       # loaded in EVERY session of an adopting repository
BRIDGE_MAX = (25, 400)         # CLAUDE.md, Cursor rule, Copilot, Gemini, Windsurf
REF_MAX = (200, 2600)          # one reference file, loaded on demand
for lang, base in editions.items():
    text = (base / "SKILL.md").read_text(encoding="utf-8")
    fm = yaml.safe_load(text.split("---")[1])
    check(len(fm["description"]) <= 1024, f"{lang} SKILL description over 1024 chars")
    check(len(fm.get("compatibility", "")) <= 500, f"{lang} SKILL compatibility over 500 chars")
    check(len(fm["name"]) <= 64, f"{lang} SKILL name too long")
    for name, (path, (ml, mt)) in {
        "SKILL.md": (base / "SKILL.md", SKILL_MAX),
        "AGENTS.md": (base / "templates/AGENTS.md", AGENTS_MAX),
    }.items():
        t = path.read_text(encoding="utf-8")
        check(len(t.splitlines()) <= ml, f"{lang} {name}: {len(t.splitlines())} lines > {ml}")
        check(tokens(t) <= mt, f"{lang} {name}: ~{tokens(t)} tokens > {mt}")
    for f in (base / "templates/agents").iterdir():
        t = f.read_text(encoding="utf-8")
        check(len(t.splitlines()) <= BRIDGE_MAX[0] and tokens(t) <= BRIDGE_MAX[1], f"{lang} bridge file {f.name} too large")
    for f in (base / "references").rglob("*.md"):
        t = f.read_text(encoding="utf-8")
        check(len(t.splitlines()) <= REF_MAX[0], f"{lang} {f.relative_to(base)}: {len(t.splitlines())} lines > {REF_MAX[0]}")
        check(tokens(t) <= REF_MAX[1] + (900 if lang == "ar" else 0), f"{lang} {f.relative_to(base)}: ~{tokens(t)} tokens")

cover = json.loads((root / "tests/rule-coverage.json").read_text(encoding="utf-8"))
for lang, base in editions.items():
    agents = (base / "templates/AGENTS.md").read_text(encoding="utf-8")
    for rule, rx in cover[lang].items():
        check(re.search(rx, agents) is not None, f"{lang} AGENTS.md does not state: {rule}")

# Every universal rule ID must be represented in each language's coverage map.
tool_only = {"U12", "U17"}   # Planned / helper: documented in rules-index, not an everyday rule
for lang, base in editions.items():
    index = (base / "references/rules-index.md").read_text(encoding="utf-8")
    ids = re.findall(r"^\| (U\d+) \|", index, re.M)
    covered = {k.split()[0] for k in cover.get(lang, {})}
    for rid in ids:
        if rid not in tool_only:
            check(rid in covered, f"{lang} rules-index rule {rid} has no coverage entry in tests/rule-coverage.json")

for b in bad:
    print("  FAIL ", b)
a = tokens((editions["en"] / "templates/AGENTS.md").read_text(encoding="utf-8"))
s = tokens((editions["en"] / "SKILL.md").read_text(encoding="utf-8"))
print(f"  {'FAIL' if bad else 'PASS'}  context budget and rule completeness: {checks} checks, {len(bad)} problem(s) (SKILL.md ~{s} tokens, AGENTS.md ~{a} tokens)")
sys.exit(1 if bad else 0)
PY
# shellcheck disable=SC2181
if [[ $? -eq 0 ]]; then ok "every binding rule is in the always-loaded file, within the context budget"; else bad "context budget"; fi
summary
