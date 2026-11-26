#!/usr/bin/env bash
# One-command setup: copies the rules, gates, CI workflows and docs starters
# into a repository, fills the placeholders you give it, and never overwrites
# a file you already have (unless --force).
#
#   bash install.sh --target <repo dir> [options]
#
#   --profile lite|standard|strict   how strict the gates are      (default: standard)
#   --stack auto|none|<a,b,c>        stacks to set up CI for       (default: auto)
#                                    node nextjs react-native dotnet php flutter
#                                    python java go rust ruby
#   --layout single|member           single repository, or a member of a
#                                    multi-repository project that uses the shared
#                                    gates of an "infra" repository (default: single)
#   --agents all|none|<a,b>          bridge files: claude cursor copilot gemini windsurf
#                                    (default: all)
#   --org <name> --project <name> --owner <handle>
#                                    replace <org>, <project>, <owner> placeholders
#   --stack-configs                  also copy recommended tool configs (opt in)
#   --update                         refresh the scripts and workflows installed earlier
#                                    (never touches AGENTS.md, docs or configs; a file you
#                                    edited is kept and the new version is written as .new)
#   --force                          overwrite existing files
#   --dry-run                        print what would happen, change nothing
set -euo pipefail

# This script needs bash 4 or newer. macOS ships bash 3.2: use a newer one if it is installed.
if (( ${ER_BASH_MAJOR:-${BASH_VERSINFO[0]}} < 4 )); then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_b" ]] && ER_BASH_MAJOR=5 exec "$_b" "$0" "$@"
  done
  echo "engineering-rules: this script needs bash 4 or newer (macOS: brew install bash)." >&2
  exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill="$(cd "${here}/.." && pwd)"
target="" profile="standard" stack="auto" layout="single" agents="all" update=0
org="" project="" owner="" force=0 dry=0 stack_configs=0

while (($#)); do
  case "$1" in
    --target) target="${2:?--target needs a directory}"; shift 2 ;;
    --profile) profile="${2:?}"; shift 2 ;;
    --stack) stack="${2:?}"; shift 2 ;;
    --layout) layout="${2:?}"; shift 2 ;;
    --agents) agents="${2:?}"; shift 2 ;;
    --org) org="${2:?}"; shift 2 ;;
    --project) project="${2:?}"; shift 2 ;;
    --owner) owner="${2:?}"; shift 2 ;;
    --stack-configs) stack_configs=1; shift ;;
    --force) force=1; shift ;;
    --update) update=1; shift ;;
    --dry-run) dry=1; shift ;;
    -h | --help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$target" ]] || { echo "--target is required (see --help)" >&2; exit 2; }
[[ -d "$target" ]] || { echo "not a directory: ${target}" >&2; exit 2; }
[[ -f "${skill}/scripts/profiles/${profile}.env" ]] || { echo "unknown profile: ${profile} (lite, standard, strict)" >&2; exit 2; }
[[ "$layout" == "single" || "$layout" == "member" ]] || { echo "--layout must be single or member" >&2; exit 2; }
target="$(cd "$target" && pwd)"

created=() skipped=() installed_files=()
version="$(cat "${skill}/VERSION" 2>/dev/null || echo unknown)"
manifest_rel=".github/engineering-rules.manifest"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# managed_pairs: "<source>\t<destination relative to the target>" for every file the
# skill owns (scripts and workflows). Documents and configs belong to you.
managed_pairs() {
  local f e
  for f in ensure-tool install-release-tool gitleaks-scan renovate-config-check local-proof stack-gates doctor load-env; do
    printf '%s\t%s\n' "${skill}/scripts/${f}.sh" ".github/scripts/${f}.sh"
  done
  for f in policy-gates feature-flag-expiry assert-sha256-lock; do
    printf '%s\t%s\n' "${skill}/scripts/${f}.mjs" ".github/scripts/${f}.mjs"
  done
  for f in docs-check.sh docs-check.mjs pr-size-check.sh pr-size-exclude.txt; do
    printf '%s\t%s\n' "${skill}/templates/${f}" ".github/scripts/${f}"
  done
  while IFS= read -r f; do
    printf '%s\t%s\n' "$f" ".github/scripts/stacks/${f#"${skill}"/scripts/stacks/}"
  done < <(find "${skill}/scripts/stacks" -type f | sort)
  # workflows: only the single-repository gates file is managed (the member layout is
  # customised with your <org> and a pinned commit, so it is yours)
  if [[ "$update" != "1" && "$layout" == "single" ]]; then
    printf '%s\t%s\n' "${skill}/templates/project-gates.yml" ".github/workflows/project-gates.yml"
  elif [[ "$update" == "1" && -f "${target}/.github/workflows/project-gates.yml" ]] && ! grep -q 'infra/.github/actions' "${target}/.github/workflows/project-gates.yml"; then
    printf '%s\t%s\n' "${skill}/templates/project-gates.yml" ".github/workflows/project-gates.yml"
  fi
  if [[ "$update" != "1" ]]; then
    for e in "${engines[@]:-}"; do
      [[ -n "$e" ]] && printf '%s\t%s\n' "${skill}/templates/stacks/${e}/ci.yml" ".github/workflows/stack-${e}.yml"
    done
  else
    for f in "${target}"/.github/workflows/stack-*.yml; do
      [[ -e "$f" ]] || continue
      e="$(basename "$f" .yml)"
      e="${e#stack-}"
      [[ -f "${skill}/templates/stacks/${e}/ci.yml" ]] && printf '%s\t%s\n' "${skill}/templates/stacks/${e}/ci.yml" ".github/workflows/stack-${e}.yml"
    done
  fi
}

# --update: refresh managed files without clobbering your edits.
if [[ "$update" == "1" ]]; then
  mpath="${target}/${manifest_rel}"
  [[ -f "$mpath" ]] || { echo "no ${manifest_rel} in ${target}: install first (or this repository was set up by an older version)" >&2; exit 2; }
  updated=0 conflicts=0 added=0 same=0
  newm="$(mktemp)"
  printf '# engineering-rules %s\n' "$version" >"$newm"
  while IFS=$'\t' read -r src rel; do
    dest="${target}/${rel}"
    new_hash="$(sha_of "$src")"
    rec="$(awk -v p="$rel" '$2 == p { print $1 }' "$mpath")"
    if [[ ! -e "$dest" ]]; then
      if ((! dry)); then mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"; [[ "$rel" == *.sh ]] && chmod +x "$dest"; fi
      echo "  added     ${rel}"; added=$((added + 1)); printf '%s  %s\n' "$new_hash" "$rel" >>"$newm"; continue
    fi
    cur="$(sha_of "$dest")"
    if [[ "$cur" == "$new_hash" ]]; then
      same=$((same + 1)); printf '%s  %s\n' "$new_hash" "$rel" >>"$newm"
    elif [[ -n "$rec" && "$cur" == "$rec" ]]; then
      if ((! dry)); then cp "$src" "$dest"; [[ "$rel" == *.sh ]] && chmod +x "$dest"; fi
      echo "  updated   ${rel}"; updated=$((updated + 1)); printf '%s  %s\n' "$new_hash" "$rel" >>"$newm"
    else
      if ((! dry)); then cp "$src" "${dest}.new"; fi
      echo "  CONFLICT  ${rel} (you changed it; the new version is in ${rel}.new)"; conflicts=$((conflicts + 1))
      [[ -n "$rec" ]] && printf '%s  %s\n' "$rec" "$rel" >>"$newm"
    fi
  done < <(managed_pairs)
  while IFS= read -r line; do
    p="${line#*  }"
    [[ "$line" == \#* ]] && continue
    grep -q "  ${p}\$" "$newm" || echo "  obsolete  ${p} (no longer shipped; delete it if you do not need it)"
  done <"$mpath"
  ((dry)) || cp "$newm" "$mpath"
  rm -f "$newm"
  if [[ -f "${target}/.github/tool-pins.env" ]] && ! cmp -s "${target}/.github/tool-pins.env" "${skill}/templates/tool-pins.env"; then
    echo "  note      .github/tool-pins.env differs from this version's pins: compare them and update the versions and checksums you want"
  fi
  echo "updated ${updated}, added ${added}, unchanged ${same}, conflicts ${conflicts} (skill version ${version})"
  exit 0
fi

# put <source> <dest relative to target> [mode]
put() {
  local src="$1" rel="$2" dest="${target}/$2"
  if [[ -e "$dest" && "$force" -ne 1 ]]; then
    skipped+=("$rel")
    return 0
  fi
  if ((dry)); then
    created+=("$rel (dry run)")
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  [[ "$rel" == *.sh ]] && chmod +x "$dest"
  created+=("$rel")
  installed_files+=("$dest")
}

# put_dir <source dir> <dest dir relative to target>
put_dir() {
  local src="$1" rel="$2" f
  while IFS= read -r f; do
    put "$f" "${rel}/${f#"$src"/}"
  done < <(find "$src" -type f | sort)
}

# --- stacks --------------------------------------------------------------------------
engines=()
if [[ "$stack" == "auto" ]]; then
  detected="$(bash "${skill}/scripts/stack-gates.sh" --root "$target" --list 2>/dev/null || true)"
  # map detected engines to templates; framework hints decide next / react native
  while read -r eng dir; do
    [[ -n "${eng:-}" ]] || continue
    case "$eng" in
      node)
        pkg="${target}/${dir}/package.json"
        tpl=node
        if grep -q '"next"' "$pkg" 2>/dev/null; then tpl=nextjs
        elif grep -qE '"(expo|react-native)"' "$pkg" 2>/dev/null; then tpl=react-native; fi
        engines+=("$tpl") ;;
      *) engines+=("$eng") ;;
    esac
  done <<<"$detected"
elif [[ "$stack" != "none" ]]; then
  IFS=',' read -ra engines <<<"$stack"
fi
# unique
_uniq=()
while IFS= read -r _e; do _uniq+=("$_e"); done < <(printf '%s\n' "${engines[@]:-}" | grep -v '^$' | sort -u)
engines=("${_uniq[@]:-}")
for e in "${engines[@]:-}"; do
  [[ -z "$e" || -d "${skill}/templates/stacks/${e}" ]] || { echo "unknown stack: ${e}" >&2; exit 2; }
done

# --- scripts ---------------------------------------------------------------------------
for f in ensure-tool install-release-tool gitleaks-scan renovate-config-check local-proof stack-gates doctor load-env; do
  put "${skill}/scripts/${f}.sh" ".github/scripts/${f}.sh"
done
for f in policy-gates feature-flag-expiry; do put "${skill}/scripts/${f}.mjs" ".github/scripts/${f}.mjs"; done
put "${skill}/scripts/assert-sha256-lock.mjs" ".github/scripts/assert-sha256-lock.mjs"
for f in docs-check.sh docs-check.mjs pr-size-check.sh pr-size-exclude.txt; do put "${skill}/templates/${f}" ".github/scripts/${f}"; done
put_dir "${skill}/scripts/stacks" ".github/scripts/stacks"
for f in "${skill}"/scripts/policy/*.json; do put "$f" ".github/policy/$(basename "$f")"; done

# --- profile + pins -----------------------------------------------------------------
profile_dest="${target}/.github/engineering-rules.env"
if [[ -e "$profile_dest" && "$force" -ne 1 ]]; then
  skipped+=(".github/engineering-rules.env")
elif ((dry)); then
  created+=(".github/engineering-rules.env (dry run)")
else
  mkdir -p "${target}/.github"
  cp "${skill}/scripts/profiles/${profile}.env" "$profile_dest"
  for e in "${engines[@]:-}"; do
    if [[ "$e" == "flutter" ]]; then
      printf '\n# Flutter: building needs the platform SDKs, so the build gate is opt-in.\n# Set STACK_FLUTTER_BUILD="apk --debug" and add build to STACK_REQUIRE to require it.\nSTACK_REQUIRE=deps,test\n' >>"$profile_dest"
    fi
  done
  created+=(".github/engineering-rules.env")
  installed_files+=("$profile_dest")
fi
put "${skill}/templates/tool-pins.env" ".github/tool-pins.env"
put "${skill}/templates/gitleaks.toml" ".gitleaks.toml"
put "${skill}/templates/pre-commit-config.yaml" ".pre-commit-config.yaml"
put "${skill}/templates/renovate.json" "renovate.json"
put "${skill}/templates/renovate-preset.json" "renovate/default.json"

# --- workflows and review files ----------------------------------------------------
if [[ "$layout" == "single" ]]; then
  put "${skill}/templates/project-gates.yml" ".github/workflows/project-gates.yml"
else
  put "${skill}/templates/project-gates.multi-repo.yml" ".github/workflows/project-gates.yml"
fi
for e in "${engines[@]:-}"; do
  [[ -n "$e" ]] && put "${skill}/templates/stacks/${e}/ci.yml" ".github/workflows/stack-${e}.yml"
done
put "${skill}/templates/PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"
put "${skill}/templates/CODEOWNERS" ".github/CODEOWNERS"

# --- rules file and docs ----------------------------------------------------------------
put "${skill}/templates/AGENTS.md" "AGENTS.md"
put "${skill}/templates/CHANGELOG.md" "CHANGELOG.md"
put "${skill}/templates/docs-map.yml" "docs/docs-map.yml"
put "${skill}/templates/required-docs.json" ".github/docs-check/required-docs.json"
put "${skill}/templates/markdownlint.jsonc" ".github/docs-check/.markdownlint.jsonc"
put_dir "${skill}/templates/docs" "docs"
if [[ ! -e "${target}/README.md" ]] && ((! dry)); then
  printf '# %s\n\nSee [docs](docs/README.md).\n' "${project:-Project name}" >"${target}/README.md"
  created+=("README.md")
fi

# --- assistant bridge files -------------------------------------------------------------
want_agent() { [[ "$agents" == "all" ]] || in_csv "$1" "$agents"; }
in_csv() { [[ ",${2// /}," == *",$1,"* ]]; }
if [[ "$agents" != "none" ]]; then
  want_agent claude && put "${skill}/templates/agents/CLAUDE.md" "CLAUDE.md"
  want_agent cursor && put "${skill}/templates/agents/cursor-rule.mdc" ".cursor/rules/engineering-rules.mdc"
  want_agent copilot && put "${skill}/templates/agents/copilot-instructions.md" ".github/copilot-instructions.md"
  want_agent gemini && put "${skill}/templates/agents/GEMINI.md" "GEMINI.md"
  want_agent windsurf && put "${skill}/templates/agents/windsurf-rule.md" ".windsurf/rules/engineering-rules.md"
fi

# --- optional stack configs -----------------------------------------------------------
if ((stack_configs)); then
  for e in "${engines[@]:-}"; do
    [[ -n "$e" && -d "${skill}/templates/stacks/${e}/configs" ]] || continue
    put_dir "${skill}/templates/stacks/${e}/configs" "."
  done
fi

# --- placeholders ------------------------------------------------------------------------
if ((! dry)) && [[ -n "$org$project$owner" ]]; then
  for f in "${installed_files[@]:-}"; do
    [[ -f "$f" ]] || continue
    # scripts are owned by the skill (and updated by --update): never rewrite them
    [[ "$f" == */.github/scripts/* ]] && continue
    # sed -i.bak (attached suffix) works on both GNU and BSD sed
    [[ -n "$org" ]] && sed -i.bak "s#<org>#${org}#g" "$f" && rm -f "${f}.bak"
    [[ -n "$project" ]] && sed -i.bak "s#<project>#${project}#g" "$f" && rm -f "${f}.bak"
    [[ -n "$owner" ]] && sed -i.bak "s#<owner>#${owner}#g" "$f" && rm -f "${f}.bak"
  done
fi

# --- manifest: remember what we installed so --update can tell your edits from ours ---
if ((! dry)); then
  mpath="${target}/${manifest_rel}"
  {
    printf '# engineering-rules %s\n' "$version"
    while IFS=$'\t' read -r src rel; do
      for c in "${created[@]:-}"; do
        if [[ "$c" == "$rel" ]]; then printf '%s  %s\n' "$(sha_of "${target}/${rel}")" "$rel"; break; fi
      done
    done < <(managed_pairs)
  } >"$mpath"
fi

# --- report -----------------------------------------------------------------------------------
echo "engineering-rules installed into ${target}"
echo "  profile: ${profile}   layout: ${layout}   stacks: ${engines[*]:-none}"
echo "  created: ${#created[@]} files   kept (already existed): ${#skipped[@]}"
((${#skipped[@]})) && printf '    kept %s\n' "${skipped[@]}"
cat <<NEXT

Next steps:
  1. Fill the placeholders:   grep -rn '<owner>\|<org>\|<project>' .github AGENTS.md renovate.json
  2. Check tool pins:         .github/tool-pins.env   (verify versions, update if newer ones exist)
  3. Install the hook:        pre-commit install
  4. Check the setup:         bash .github/scripts/doctor.sh
  5. Prove the gates:         git add -A && git commit -m "chore: adopt engineering rules" && bash .github/scripts/local-proof.sh
NEXT
