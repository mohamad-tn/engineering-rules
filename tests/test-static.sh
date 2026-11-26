#!/usr/bin/env bash
# Static checks over the whole repository: shell, JavaScript, JSON, YAML, GitHub
# workflows, markdown, links, and a scan for secret-looking strings. Checks whose
# tool is not installed are skipped and reported as skipped.
# shellcheck disable=SC2015
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
cd "$REPO_ROOT" || exit 2

echo "== pinned tool platform guard"
arch_tmp="$(mktemp -d)"
cat >"${arch_tmp}/uname" <<'UNAME'
#!/bin/sh
case "${1:-}" in
  -s) echo Linux ;;
  -m) echo aarch64 ;;
  *) echo Linux ;;
esac
UNAME
chmod +x "${arch_tmp}/uname"
arch_out="$(PATH="${arch_tmp}:${PATH}" bash skills/engineering-rules/scripts/ensure-tool.sh __arch_test__ 2>&1)"; arch_rc=$?
rm -rf "$arch_tmp"
if [[ "$arch_rc" == 1 ]] && grep -q "pinned downloads support Linux x86_64 only" <<<"$arch_out"; then
  ok "unsupported architecture is rejected before download"
else
  bad "unsupported architecture guard (rc=${arch_rc})"
fi

echo "== test runner"
runner_out="$(bash tests/run-all.sh __unknown_suite__ 2>&1)"; runner_rc=$?
if [[ "$runner_rc" == 2 ]] && grep -q "unknown test suite" <<<"$runner_out" && ! grep -q "ALL TESTS PASSED" <<<"$runner_out"; then
  ok "unknown test suite is rejected"
else
  bad "unknown suite must fail explicitly (rc=${runner_rc})"
fi

echo "== shell"
shells=()
while IFS= read -r _f; do shells+=("$_f"); done < <(find . -name '*.sh' -not -path './tests/fixtures/*' -not -path './tests/stubs/*' -not -path './.git/*' | sort)
for f in "${shells[@]}"; do bash -n "$f" || bad "syntax: $f"; done
ok "bash -n on ${#shells[@]} scripts"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -e SC2154,SC1091 "${shells[@]}" >/tmp/shellcheck.out 2>&1; then ok "shellcheck on ${#shells[@]} scripts"; else bad "shellcheck"; head -n 30 /tmp/shellcheck.out >&2; fi
else skipped "shellcheck (not installed)"; fi

echo "== javascript, json, yaml"
mjs=()
while IFS= read -r _f; do mjs+=("$_f"); done < <(find . \( -name '*.mjs' -o -name '*.cjs' \) -not -path '*/node_modules/*' -not -path './tests/fixtures/*' | sort)
for f in "${mjs[@]}"; do node --check "$f" || bad "node --check $f"; done
ok "node --check on ${#mjs[@]} files"
python3 - <<'PY' && ok "JSON and YAML files parse" || bad "JSON/YAML parse"
import glob, json, sys
from pathlib import Path
import tempfile
try:
    import yaml
except ImportError:
    print("PyYAML is required; install tests/requirements.txt")
    sys.exit(2)
bad = 0
def config_files(root, suffixes):
    return sorted(f for f in Path(root).rglob("*") if f.is_file() and f.suffix in suffixes
                  and not {"node_modules", "fixtures", ".git"}.intersection(f.parts))
with tempfile.TemporaryDirectory(prefix="er-hidden-config-") as tmp:
    hidden = Path(tmp) / ".github/workflows/hidden.yaml"
    hidden.parent.mkdir(parents=True)
    hidden.write_text("broken: [\n", encoding="utf-8")
    assert hidden in config_files(tmp, {".yml", ".yaml"}), "hidden YAML was omitted"
    try:
        yaml.safe_load(hidden.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        pass
    else:
        raise AssertionError("malformed hidden YAML was accepted")
for f in config_files(".", {".json"}):
    try: json.load(open(f, encoding="utf-8"))
    except Exception as e: print("JSON", f, e); bad += 1
for f in config_files(".", {".yml", ".yaml"}):
    try: yaml.safe_load(open(f, encoding="utf-8"))
    except Exception as e: print("YAML", f, e); bad += 1
for f in glob.glob("skills/engineering-rules/templates/stacks/*/ci.yml") + glob.glob("skills/engineering-rules-ar/templates/stacks/*/ci.yml"):
    text = open(f, encoding="utf-8").read()
    if "dorny/paths-filter@" in text:
        data = yaml.safe_load(text) or {}
        if (data.get("permissions") or {}).get("pull-requests") != "read":
            print("YAML permissions", f, "must grant pull-requests: read for paths-filter")
            bad += 1
sys.exit(1 if bad else 0)
PY

echo "== github workflows"
AL="$(command -v actionlint || true)"; [[ -z "$AL" && -x /tmp/actionlint ]] && AL=/tmp/actionlint
if [[ -n "$AL" ]]; then
  tmp="$(mktemp -d)"; mkdir -p "$tmp/.github/workflows"
  git -C "$tmp" init -q
  n=0
  while IFS= read -r f; do cp "$f" "$tmp/.github/workflows/w$((n++)).yml"; done < <(find skills/engineering-rules/templates .github/workflows -name '*.yml' \( -path '*workflows*' -o -name 'project-gates*.yml' -o -name 'ci.yml' \) 2>/dev/null | sort -u)
  if (cd "$tmp" && "$AL" -color=false) >/tmp/actionlint.out 2>&1; then ok "actionlint on ${n} workflow templates"; else bad "actionlint"; head -n 30 /tmp/actionlint.out >&2; fi
  rm -rf "$tmp"
else skipped "actionlint (not installed)"; fi

echo "== markdown and links"
if command -v npx >/dev/null && [[ -f skills/engineering-rules/templates/markdownlint.jsonc ]]; then
  if npx --yes markdownlint-cli2@0.23.3 --config skills/engineering-rules/templates/markdownlint.jsonc "**/*.md" "#node_modules" "#tests/fixtures" >/tmp/mdlint.out 2>&1; then ok "markdownlint"; else bad "markdownlint"; tail -n 25 /tmp/mdlint.out >&2; fi
else skipped "markdownlint (npx not available)"; fi
LY="$(command -v lychee || find "${HOME}/.cache/engineering-rules-skill/tools" -name lychee -type f 2>/dev/null | head -n 1 || true)"
if [[ -n "$LY" ]]; then
  if "$LY" --version >/tmp/lychee-version.out 2>&1; then
    if "$LY" --offline --include-fragments --no-progress --format compact --exclude-path node_modules --exclude-path tests/fixtures "**/*.md" >/tmp/lychee.out 2>&1; then ok "internal links and anchors"; else bad "links"; tail -n 25 /tmp/lychee.out >&2; fi
  elif grep -qE 'Exec format error|cannot execute binary file' /tmp/lychee-version.out; then
    skipped "lychee (cached binary is incompatible with $(uname -m))"
  else
    bad "lychee executable is present but cannot report its version"; cat /tmp/lychee-version.out >&2
  fi
else skipped "lychee (not installed)"; fi

echo "== ci-local safety"
if grep -qE 'gh auth token|--secret GITHUB_TOKEN' skills/engineering-rules/scripts/ci-local.sh; then bad "ci-local passes the host GitHub token to workflow code"; else ok "ci-local does not fetch or pass a host GitHub token"; fi
grep -Fq -- '--secret-file /dev/null' skills/engineering-rules/scripts/ci-local.sh && ok "ci-local disables act's default secrets file" || bad "ci-local default secret file is not disabled"

echo "== hygiene"
# Secret-looking strings and private hosts must never appear in the repository.
if grep -rIEn --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=fixtures \
  -e '(ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}' -e 'AKIA[0-9A-Z]{16}' -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
  -e 'sk-[A-Za-z0-9]{32,}' -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' . >/tmp/secrets.out 2>&1; then
  bad "secret-looking strings found"; head -n 10 /tmp/secrets.out >&2
else ok "no secret-looking strings"; fi
if find . -not -path './.git/*' -not -path '*/node_modules/*' \( -name '.env' -o -name '*.pem' -o -name '*.p12' -o -name '*.keystore' -o -name '*.jks' \) | grep -q .; then bad "secret-like files tracked"; else ok "no .env, key or keystore files"; fi
# publish-prep fills every repository-level placeholder.
# After a real publish the live tree has no placeholders, so the fill path is
# also proven on a tiny isolated tree. The live tree is then checked for leftovers.
mini="$(mktemp -d)"
mkdir -p "$mini/tools"
cp tools/publish-prep.sh "$mini/tools/"
printf 'MIT License\n\nCopyright (c) __YEAR__ __AUTHOR__\n' >"$mini/LICENSE"
printf 'https://github.com/__GH_OWNER__/__GH_REPO__\n' >"$mini/README.md"
if bash "$mini/tools/publish-prep.sh" --owner octo-example --repo demo-rules --author "Octo Example" --year 2026 >/dev/null 2>&1 \
  && grep -q 'Copyright (c) 2026 Octo Example' "$mini/LICENSE" \
  && grep -q 'https://github.com/octo-example/demo-rules' "$mini/README.md" \
  && ! grep -qE '__GH_OWNER__|__GH_REPO__|__AUTHOR__|__YEAR__' "$mini/LICENSE" "$mini/README.md" \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"owner":"octo-example","repo":"demo-rules","author":"Octo Example"}' "$mini/tools/publish.json"; then
  ok "publish-prep fills placeholders"
else
  bad "publish-prep"
fi
rm -rf "$mini"
if grep -rqE '__GH_OWNER__|__GH_REPO__|__AUTHOR__|__YEAR__' . --exclude-dir=tests --exclude=publish-prep.sh; then
  # Unpublished development tree: prove the script against a full copy.
  prep="$(mktemp -d)"
  tar --exclude=.git -cf - . | tar -xf - -C "$prep"
  if bash "$prep/tools/publish-prep.sh" --owner octo-example --author "Octo Example" --year 2026 >/dev/null 2>&1 \
    && ! grep -rqE '__GH_OWNER__|__GH_REPO__|__AUTHOR__|__YEAR__' "$prep" --exclude-dir=tests --exclude=publish-prep.sh \
    && grep -q 'Copyright (c) 2026 Octo Example' "$prep/LICENSE" \
    && (cd "$prep" && python3 tools/build-site.py --check >/dev/null && bash tools/build-llms.sh --check >/dev/null); then
    ok "publish-prep fills all placeholders and the generated files stay current"
  else
    bad "publish-prep on unpublished tree"
  fi
  rm -rf "$prep"
else
  if grep -qE 'Copyright \(c\) [0-9]{4} .+' LICENSE && ! grep -q '__AUTHOR__' LICENSE && python3 -c 'import json; d=json.load(open("tools/publish.json")); assert d["owner"] and d["repo"] and d["author"]'; then
    ok "published tree has no leftover placeholders"
  else
    bad "published tree placeholders or LICENSE"
  fi
fi
# Generated files must be current; marketplace manifests and eval data must parse.
python3 tools/build-site.py --check >/tmp/site-check.out 2>&1 && ok "site/ is current" || { bad "site/ is out of date"; cat /tmp/site-check.out >&2; }
python3 - <<'PY' && ok "Arabic document title contains plain text, not bdi markup" || bad "Arabic title contains invalid bdi markup"
import re
text = open("site/ar/index.html", encoding="utf-8").read()
title = re.search(r"<title>(.*?)</title>", text, re.S)
assert title and "<bdi" not in title.group(1)
PY
bash tools/build-llms.sh --check >/tmp/llms-check.out 2>&1 && ok "llms-full.txt is current" || { bad "llms-full.txt out of date"; cat /tmp/llms-check.out >&2; }
python3 - <<'PY' && ok "plugin manifests, eval data and CITATION parse" || bad "manifest/eval parse"
import json, yaml
for f in (".claude-plugin/plugin.json", ".claude-plugin/marketplace.json", "evals/trigger-prompts.json"):
    json.load(open(f))
m = json.load(open(".claude-plugin/marketplace.json"))
assert m["plugins"] and m["plugins"][0]["source"] and m["owner"]["name"]
yaml.safe_load(open("CITATION.cff"))
PY
# Required files of a publishable repository.
for f in README.md README.ar.md LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md CHANGELOG.md AGENTS.md CLAUDE.md CITATION.cff llms.txt llms-full.txt .claude-plugin/plugin.json .claude-plugin/marketplace.json site/index.html site/ar/index.html skills/engineering-rules/SKILL.md skills/engineering-rules-ar/SKILL.md; do
  [[ -f "$f" ]] && ok "present: $f" || bad "missing: $f"
done
head -n 5 skills/engineering-rules/SKILL.md | grep -q '^name: engineering-rules$' && ok "SKILL.md frontmatter name matches its folder" || bad "SKILL.md name"
summary
