#!/usr/bin/env bash
# shellcheck shell=bash
# Node.js engine: plain Node, Next.js, React, React Native / Expo, Vue / Nuxt,
# Angular, Svelte, NestJS, Express, Vite... Works with npm, pnpm, yarn and bun.

# pj <js expression on p>: reads package.json of the current directory.
pj() { node -e "const p=require('./package.json');const v=($1);if(v!==undefined&&v!==null)console.log(typeof v==='object'?JSON.stringify(v):v)" 2>/dev/null; }

has_script() { [[ -n "$(pj "p.scripts && p.scripts['$1']")" ]]; }
has_dep() { [[ -n "$(pj "(p.dependencies&&p.dependencies['$1'])||(p.devDependencies&&p.devDependencies['$1'])||(p.peerDependencies&&p.peerDependencies['$1'])")" ]]; }
has_bin() { [[ -x "node_modules/.bin/$1" ]] || { [[ -n "${NODE_LOCK_DIR:-}" && -x "${NODE_LOCK_DIR}/node_modules/.bin/$1" ]]; }; }

node_framework() {
  has_dep next && { echo nextjs; return; }
  has_dep expo && { echo expo; return; }
  has_dep react-native && { echo react-native; return; }
  has_dep nuxt && { echo nuxt; return; }
  has_dep @angular/core && { echo angular; return; }
  has_dep @nestjs/core && { echo nestjs; return; }
  has_dep svelte && { echo svelte; return; }
  has_dep vue && { echo vue; return; }
  has_dep react && { echo react; return; }
  has_dep express && { echo express; return; }
  echo node
}

# first_script <names...>: prints the first script name that exists.
first_script() {
  local s
  for s in "$@"; do has_script "$s" && { echo "$s"; return 0; }; done
  return 1
}

run_node() {
  local pm="" lockdir="" install=() runner=() audit=()
  local lock_candidates=() lock_name lock_parent lock_list lock_top
  lock_parent="$(pwd -P)"
  lock_top="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
  # The nearest directory owns the lock. An independent child project must not
  # conflict with a different package manager used by a parent in the same repo.
  while :; do
    for lock_name in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock bun.lockb bun.lock; do
      [[ -f "${lock_parent}/${lock_name}" ]] && lock_candidates+=("${lock_parent}/${lock_name}")
    done
    ((${#lock_candidates[@]})) && break
    [[ "$lock_parent" == "$lock_top" || "$lock_parent" == "/" ]] && break
    lock_parent="$(dirname "$lock_parent")"
  done
  if ((${#lock_candidates[@]} > 1)); then
    lock_list="$(printf '%s, ' "${lock_candidates[@]}")"
    fail deps "multiple lockfiles found (${lock_list%, }): keep one package-manager lockfile per project/workspace"
    return 0
  fi
  if ((${#lock_candidates[@]} == 1)); then lockdir="$(dirname "${lock_candidates[0]}")"; fi
  NODE_LOCK_DIR="$lockdir"
  local level="${AUDIT_LEVEL:-high}"

  if [[ -n "$lockdir" ]]; then
    if [[ -f "${lockdir}/pnpm-lock.yaml" ]]; then
      pm=pnpm; install=(pnpm install --frozen-lockfile); runner=(pnpm run); audit=(pnpm audit --prod --audit-level "$level")
    elif [[ -f "${lockdir}/yarn.lock" ]]; then
      pm=yarn; runner=(yarn run)
      if [[ -f "${lockdir}/.yarnrc.yml" ]]; then
        install=(yarn install --immutable); audit=(yarn npm audit --environment production --severity "$level")
      else
        install=(yarn install --frozen-lockfile); audit=(yarn audit --groups dependencies --level "$level")
      fi
    elif [[ -f "${lockdir}/bun.lockb" || -f "${lockdir}/bun.lock" ]]; then
      pm=bun; install=(bun install --frozen-lockfile); runner=(bun run); audit=()
    else
      pm=npm; install=(npm ci --no-audit --no-fund); runner=(npm run --silent); audit=(npm audit --omit=dev --audit-level="$level")
    fi
  fi

  local fw
  fw="$(node_framework)"
  echo "  framework: ${fw}${pm:+, package manager: ${pm}}"

  # A published library (not private, has an entry point) may legitimately ship no
  # lockfile: warn and install without one. An application must commit its lockfile.
  local library=0
  if [[ -z "$pm" && -z "$(pj "p.private === true ? 'x' : undefined")" && -n "$(pj "(p.main||p.exports||p.module||p.types||p.bin) ? 'x' : undefined")" ]]; then
    library=1
    if have npm; then
      pm=npm; install=(npm install --no-audit --no-fund --no-package-lock); runner=(npm run --silent); audit=()
      warn lockfile "library without a lockfile: dependency versions are not pinned for CI"
    fi
  fi

  # deps ----------------------------------------------------------------------
  if [[ -z "$pm" ]]; then
    fail deps "no lockfile: commit package-lock.json, pnpm-lock.yaml, yarn.lock or bun.lockb"
  elif ! have "${pm}"; then
    notrun deps "${pm} is not installed"
  elif [[ "${STACK_SKIP_INSTALL:-0}" == "1" ]]; then
    skip deps "STACK_SKIP_INSTALL=1"
  elif [[ "${NODE_DEPS_DONE:-}" == *"|${lockdir}|"* ]]; then
    skip deps "installed already for ${lockdir}"
  else
    # Positional arguments keep apostrophes and spaces out of shell source.
    # shellcheck disable=SC2016
    gate_net deps -- bash -c 'cd -- "$1" && shift && "$@"' _ "${lockdir:-$PWD}" "${install[@]}"
    NODE_DEPS_DONE="${NODE_DEPS_DONE:-}|${lockdir}|"
  fi
  [[ -n "$pm" ]] || return 0
  have "$pm" || return 0
  ((library)) && audit=()

  local script
  # format ----------------------------------------------------------------------
  if script="$(first_script format:check prettier:check check:format format-check)"; then
    gate format -- "${runner[@]}" "$script"
  elif has_bin prettier && { any_file ".prettierrc*" "prettier.config.*" || [[ -n "$(pj "p.prettier")" ]]; }; then
    gate format -- npx --no-install prettier --check .
  elif has_bin biome && [[ -f biome.json || -f biome.jsonc ]]; then
    gate format -- npx --no-install biome format .
  else
    skip format "no format:check script and no prettier/biome config"
  fi

  # lint ------------------------------------------------------------------------
  if script="$(first_script lint lint:ci eslint)"; then
    gate lint -- "${runner[@]}" "$script"
  elif has_bin eslint && any_file "eslint.config.*" ".eslintrc*"; then
    gate lint -- npx --no-install eslint .
  elif has_bin biome && [[ -f biome.json || -f biome.jsonc ]]; then
    gate lint -- npx --no-install biome check .
  else
    skip lint "no lint script and no eslint/biome config"
  fi

  # types -----------------------------------------------------------------------
  if script="$(first_script typecheck type-check check-types tsc)"; then
    gate types -- "${runner[@]}" "$script"
  elif [[ -f tsconfig.json ]] && has_bin tsc; then
    gate types -- npx --no-install tsc --noEmit
  else
    skip types "no typecheck script and no tsconfig.json with typescript installed"
  fi

  # test ------------------------------------------------------------------------
  if has_script test && [[ "$(pj "p.scripts.test")" != *"no test specified"* ]]; then
    gate test -- "${runner[@]}" test
  else
    skip test "no test script"
  fi

  # build -----------------------------------------------------------------------
  if has_script build; then
    gate build -- env NEXT_TELEMETRY_DISABLED=1 "${runner[@]}" build
  else
    na build "no build script defined: nothing to build"
  fi

  # audit -----------------------------------------------------------------------
  if ((library)); then
    skip audit "library without a lockfile: audit needs one"
  elif ((${#audit[@]} == 0)); then
    skip audit "${pm} has no built-in audit; rely on your dependency bot"
  else
    gate_net audit -- "${audit[@]}"
  fi

  # duplication -----------------------------------------------------------------
  if [[ -f .jscpd.json ]] && has_bin jscpd; then
    gate dup -- npx --no-install jscpd
  fi

  # framework extras ------------------------------------------------------------
  case "$fw" in
    nextjs)
      if [[ -n "${BACKEND_URL_ENV:-}" || -n "${API_BASE_URL:-}" ]] && [[ -d "${CLIENT_BUNDLE_DIR:-.next/static}" ]]; then
        gate bundle-scan -- node "${STACK_TOOLS_DIR}/scan-client-bundle.mjs"
      else
        skip bundle-scan "set API_BASE_URL (or BACKEND_URL_ENV) and build first to scan the client bundle"
      fi
      ;;
    react | vue | nuxt | svelte | angular)
      if [[ -d "${CLIENT_BUNDLE_DIR:-}" && -n "${API_BASE_URL:-}" ]]; then
        gate bundle-scan -- node "${STACK_TOOLS_DIR}/scan-client-bundle.mjs"
      fi
      ;;
    expo | react-native)
      gate secrets-files -- env SOURCE_ROOTS="${SOURCE_ROOTS:-src/,app/,components/,screens/,lib/}" node "${STACK_TOOLS_DIR}/check-tracked-secrets.mjs"
      if [[ "$fw" == "expo" ]] && has_bin expo; then
        gate_net expo-export -- npx --no-install expo export --platform android
      fi
      ;;
  esac
}
