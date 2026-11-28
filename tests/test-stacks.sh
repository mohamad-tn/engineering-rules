#!/usr/bin/env bash
# Stack-gate tests. Part 1 runs REAL toolchains (skipped when a tool is not
# installed). Part 2 runs engines against stub tools to verify the commands an
# engine issues for toolchains we cannot install everywhere (Flutter, Maven,
# Gradle, Laravel, Expo, Rails).
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

need() { command -v "$1" >/dev/null 2>&1 || { skipped "$2 (needs $1)"; return 1; }; }

echo "== real toolchains"
if need go "go fixtures"; then
  check_fixture "go: good project passes" go/good pass "test +PASS"
  check_fixture "go: bad formatting and failing test fail" go/bad fail "format +FAIL"
fi
if need cargo "rust fixtures"; then
  if cargo clippy --version >/dev/null 2>&1; then
    check_fixture "rust: good project passes" rust/good pass "lint +PASS"
    check_fixture "rust: clippy warning fails" rust/bad fail "lint +FAIL"
  else
    check_fixture "rust: good project passes" rust/good pass "test +PASS"
    skipped "rust clippy cases (needs clippy)"
  fi
fi
if need python3 "python fixtures"; then
  check_fixture "python: good project passes" python/good pass "lint +PASS" STACK_SKIP_GATES=audit
  check_fixture "python: lint, format and test failures" python/bad fail "lint +FAIL"
  check_fixture "python: unpinned requirements fail" python/unpinned fail "pinned +FAIL"
  dir="$(fixture_copy python/good)"
  printf 'pytest\n' >"$dir/requirements-dev.txt"
  run_stack "$dir" STACK_REQUIRE=pinned STACK_SKIP_GATES=deps,format,lint,types,test,build,audit
  if [[ "$RC" == 1 ]] && grep -q 'requirements-dev.txt:1: requirement must use one exact == version pin: pytest' <<<"$OUT"; then
    ok "python: unpinned development requirements fail"
  else
    bad "python: unpinned development requirements were accepted"; printf '%s\n' "$OUT" | tail -n 10 >&2
  fi
  rm -rf "$dir"
  dir="$(fixture_copy python/good)"
  mkdir -p "$dir/requirements"
  printf '%s\n' '-r requirements/extra.txt' >"$dir/requirements-dev.txt"
  printf '%s\n' '-c ../constraints.txt' >"$dir/requirements/extra.txt"
  printf 'pytest\n' >"$dir/constraints.txt"
  run_stack "$dir" STACK_REQUIRE=pinned STACK_SKIP_GATES=deps,format,lint,types,test,build,audit
  if [[ "$RC" == 1 ]] && grep -q 'constraints.txt:1: requirement must use one exact == version pin: pytest' <<<"$OUT"; then
    ok "python: unpinned requirements in nested -r/-c files fail"
  else
    bad "python: unpinned nested requirements were accepted"; printf '%s\n' "$OUT" | tail -n 10 >&2
  fi
  rm -rf "$dir"
  dir="$(fixture_copy python/good)"
  for bad_req in \
    'requests; python_version == "3.12"' \
    'requests>=2; python_version == "3.12"' \
    'requests @ https://example.invalid/requests.whl' \
    '-e git+https://example.invalid/repo.git@main#egg=thing'; do
    printf '%s\n' "$bad_req" >"$dir/requirements-dev.txt"
    run_stack "$dir" STACK_REQUIRE=pinned STACK_SKIP_GATES=deps,format,lint,types,test,build,audit
    if [[ "$RC" == 1 ]] && grep -qE 'pinned +FAIL' <<<"$OUT"; then
      ok "python: unpinned PEP 508/direct/editable requirement is rejected"
    else
      bad "python: accepted unsafe requirement: $bad_req"; printf '%s\n' "$OUT" | tail -n 8 >&2
    fi
  done
  printf '# ordinary comment\npytest==8.3.4\n' >"$dir/requirements-dev.txt"
  run_stack "$dir" STACK_REQUIRE=pinned STACK_SKIP_GATES=deps,format,lint,types,test,build,audit
  if [[ "$RC" == 0 ]] && grep -qE 'pinned +PASS' <<<"$OUT"; then ok "python: full-line comments are ignored by pin checker"; else bad "python: valid comment rejected"; fi
  printf 'pytest \\\n' >"$dir/requirements-dev.txt"
  run_stack "$dir" STACK_REQUIRE=pinned STACK_SKIP_GATES=deps,format,lint,types,test,build,audit
  if [[ "$RC" == 1 ]] && grep -qE 'pinned +FAIL' <<<"$OUT"; then ok "python: incomplete requirement continuation fails"; else bad "python: incomplete continuation was accepted"; fi
  rm -rf "$dir"
fi
if need bundle "ruby fixtures"; then
  check_fixture "ruby: good project passes" ruby/good pass "test +PASS" STACK_SKIP_GATES=audit
  check_fixture "ruby: failing test fails" ruby/bad fail "test +FAIL"
fi
if need dotnet "dotnet fixtures"; then
  mkdir -p /tmp/empty-nuget-source
  offline='STACK_CMD_DEPS=dotnet restore --source /tmp/empty-nuget-source'
  # the fixture has no test project, so "test" is not required here
  check_fixture "dotnet: good project passes" dotnet/good pass "build +PASS" "$offline" STACK_REQUIRE=deps,build
  check_fixture "dotnet: warning-as-error fails the build" dotnet/bad fail "build +FAIL" "$offline" STACK_REQUIRE=deps,build
fi
if need php "php fixtures"; then
  check_fixture "php: good project passes (test override)" php/good pass "test +PASS" "STACK_CMD_TEST=php tests/run.php"
  check_fixture "php: syntax error fails" php/bad fail "syntax +FAIL"
  check_fixture "php: no test runner is a required-gate failure" php/good fail "required gate|Required gates"
fi
if need npm "node fixtures"; then
  check_fixture "node: good project passes" node/good pass "build +PASS"
  check_fixture "node: failing test fails" node/bad fail "test +FAIL"
  check_fixture "node: missing lockfile fails" node/nolock fail "no lockfile"
  dir="$(fixture_copy node/good)"
  cp "$dir/package-lock.json" "$dir/pnpm-lock.yaml"
  run_stack "$dir" STACK_ONLY=deps
  if [[ "$RC" == 1 ]] && grep -q "multiple lockfiles found" <<<"$OUT"; then
    ok "node: multiple lockfiles fail with an explicit manager-conflict message"
  else
    bad "node: ambiguous lockfiles were not rejected"; printf '%s\n' "$OUT" | tail -n 10 >&2
  fi
  rm -rf "$dir"
  check_fixture "react (vite): build passes" react/good pass "framework: react" STACK_SKIP_GATES=audit
  check_fixture "next.js: build passes" nextjs/good pass "framework: nextjs" STACK_SKIP_GATES=audit
  # the vulnerable Next.js version in the fixture must be caught by the audit gate
  dir="$(fixture_copy nextjs/good)"
  run_stack "$dir" STACK_ONLY=deps,audit STACK_REQUIRE=deps
  if grep -qE "audit +NOT RUN" <<<"$OUT"; then skipped "next.js: audit finds known vulnerabilities (registry unreachable)"
  elif [[ "$RC" == 1 ]] && grep -qE "audit +FAIL" <<<"$OUT"; then ok "next.js: audit gate catches known vulnerabilities"
  else bad "next.js: audit gate did not report the vulnerable dependency"; printf '%s\n' "$OUT" | tail -n 12 >&2; fi
  rm -rf "$dir"
fi

if need cmake "c++ fixtures"; then
  check_fixture "c++ (cmake): good project passes" cpp/good pass "test +PASS" STACK_REQUIRE=deps,build,test
  check_fixture "c++ (cmake): failing test fails" cpp/bad fail "test +FAIL"
fi
if command -v tofu >/dev/null 2>&1 || command -v terraform >/dev/null 2>&1; then
  check_fixture "terraform: formatted, valid code passes" terraform/good pass "types +PASS" STACK_REQUIRE=deps,format,types STACK_SKIP_GATES=audit
  check_fixture "terraform: unformatted code fails fmt" terraform/bad fail "format +FAIL" STACK_SKIP_GATES=audit
else skipped "terraform fixtures (needs tofu or terraform)"; fi
if command -v hadolint >/dev/null 2>&1; then
  check_fixture "docker: clean Dockerfile passes hadolint" docker/good pass "lint +PASS"
  check_fixture "docker: Dockerfile with findings fails hadolint" docker/bad fail "lint +FAIL"
else skipped "docker fixtures (needs hadolint)"; fi

echo "== policy of the runner"
if need npm "runner policy"; then
  dir="$(fixture_copy node/good)"
  run_stack "$dir" STACK_REQUIRE=deps,lint,types,test
  if [[ "$RC" == 1 ]] && grep -q "types" <<<"$OUT" && grep -q "Required gates that did not run" <<<"$OUT"; then ok "required gate that was skipped fails the run"; else bad "required-gate policy"; fi
  run_stack "$dir" STACK_STRICT=1
  if [[ "$RC" == 1 ]]; then ok "strict mode requires format, lint, types, audit"; else bad "strict mode did not fail"; fi
  run_stack "$dir" STACK_CMD_LINT=false
  if [[ "$RC" == 1 ]] && grep -qE "lint +FAIL" <<<"$OUT"; then ok "STACK_CMD_<GATE> replaces a gate command"; else bad "command override"; fi
  run_stack "$dir" STACK_SKIP_GATES=lint
  if [[ "$RC" == 0 ]] && grep -q "disabled by STACK_SKIP_GATES" <<<"$OUT"; then ok "STACK_SKIP_GATES disables a gate"; else bad "skip gates"; fi
  rm -rf "$dir"
  empty="$(mktemp -d)"; echo "hello" >"$empty/README.md"; git_init "$empty"
  run_stack "$empty"
  if [[ "$RC" == 3 ]] && grep -q "not a pass" <<<"$OUT"; then ok "no supported stack is exit 3, never a pass"; else bad "empty repository: rc=$RC"; fi
  rm -rf "$empty"
fi

echo "== monorepo detection"
if need go "monorepo" && need npm "monorepo"; then
  mono="$(mktemp -d)"
  mkdir -p "$mono/web" "$mono/api" "$mono/mobile"
  cp -a "${FIXTURES}/node/good/." "$mono/web/"
  cp -a "${FIXTURES}/go/good/." "$mono/api/"
  cp -a "${FIXTURES}/expo/good/." "$mono/mobile/"
  git_init "$mono"
  listing="$(bash "${SKILL}/scripts/stack-gates.sh" --root "$mono" --list)"
  if grep -qE '^go +api' <<<"$listing" && grep -qE '^node +web' <<<"$listing" && grep -qE '^node +mobile' <<<"$listing"; then ok "monorepo: web, api and mobile projects are all detected"; else bad "monorepo detection: $listing"; fi
  run_stack "$mono" STACK_SKIP_GATES=audit STACK_SKIP_INSTALL=1
  if [[ "$RC" == 0 ]] && grep -q "== go · api" <<<"$OUT" && grep -q "== node · web" <<<"$OUT"; then ok "monorepo: every project runs"; else bad "monorepo run rc=$RC"; printf '%s\n' "$OUT" | tail -n 15 >&2; fi
  rm -rf "$mono"
fi

echo "== stubbed toolchains (command-level tests)"
export PATH="${STUBS}/bin:${PATH}"

# stub_case <name> <fixture> <expect> <pattern> <log pattern ...> -- [env ...]
stub_case() {
  local name="$1" fx="$2" expect="$3" pattern="$4"
  shift 4
  local patterns=()
  while (($#)) && [[ "$1" != "--" ]]; do patterns+=("$1"); shift; done
  [[ "${1:-}" == "--" ]] && shift
  local dir log want=0
  dir="$(fixture_copy "$fx")"
  log="$(mktemp)"
  [[ "$expect" == "fail" ]] && want=1
  run_stack "$dir" STUB_LOG="$log" STACK_SKIP_INSTALL="${SKIP_INSTALL:-0}" "$@"
  local problems=""
  [[ "$RC" == "$want" ]] || problems+=" exit=${RC} (wanted ${want});"
  [[ -z "$pattern" ]] || grep -qE -- "$pattern" <<<"$OUT" || problems+=" output lacks /${pattern}/;"
  local p
  for p in "${patterns[@]}"; do grep -qE -- "$p" "$log" || problems+=" command log lacks /${p}/;"; done
  if [[ -z "$problems" ]]; then ok "$name"; else bad "${name}:${problems}"; printf '%s\n' "$OUT" | tail -n 20 | sed 's/^/        /' >&2; echo "        log:" >&2; sed 's/^/        /' "$log" >&2; fi
  rm -rf "$dir" "$log"
}

stub_case "flutter: pub get, format, analyze, test" flutter/good pass "deps +PASS" \
  "flutter pub get" "dart format --output=none --set-exit-if-changed" "flutter analyze" "flutter test" -- STACK_SKIP_GATES=build
stub_case "flutter: failing analyzer fails the run" flutter/good fail "lint +FAIL" -- STUB_EXIT_FLUTTER=1
stub_case "flutter: build runs only when configured" flutter/good pass "build +PASS" "flutter build apk --debug" -- "STACK_FLUTTER_BUILD=apk --debug"
stub_case "swift: resolve, test, build" swift/good pass "swift: " "swift package resolve" "swift test" "swift build" --
stub_case "swift: failing swift test fails the run" swift/good fail "test +FAIL" -- STUB_EXIT_SWIFT=1
stub_case "maven: wrapper, spotless, verify, package" java-maven/good pass "framework: spring-boot" \
  "mvnw .*dependency:resolve" "mvnw .*spotless:check" "mvnw .*verify" "mvnw .*package" --
dir="$(fixture_copy java-maven/good)"
log="$(mktemp)"
run_stack "$dir" STUB_LOG="$log" STACK_REQUIRE=deps \
  "STACK_CMD_DEPS=printf '%s\\n' '429-command-called' >> \"\$STUB_LOG\"; printf '%s\\n' 'HTTP 429 Too Many Requests' >&2; exit 22"
called="$(grep -c '^429-command-called$' "$log" || true)"
if [[ "$RC" == 1 && "$called" == 1 ]] && grep -qE 'deps +NOT RUN' <<<"$OUT"; then
  ok "maven: HTTP 429 is NOT RUN, override runs once, and required deps still block"
else
  bad "maven: HTTP 429 classification rc=$RC calls=$called"
  printf '%s\n' "$OUT" | tail -n 15 >&2
fi
rm -rf "$dir" "$log"
stub_case "maven: failing build tool fails the run" java-maven/good fail "test +FAIL" -- STUB_EXIT_MVNW=1
stub_case "gradle: wrapper check and assemble" java-gradle/good pass "build tool: gradle" "gradlew .*check" "gradlew .*assemble" --
SKIP_INSTALL=0

# laravel: real composer and php; tool binaries under vendor/bin are stubs
if need php "laravel stub" && need composer "laravel stub"; then
dir="$(fixture_copy laravel/good)"
mkdir -p "$dir/vendor/laravel/framework" "$dir/vendor/bin"
cp "${STUBS}/stub.sh" "$dir/vendor/bin/pint"
cp "${STUBS}/stub.sh" "$dir/vendor/bin/phpstan"
printf 'level: 5\n' >"$dir/phpstan.neon"
log="$(mktemp)"
run_stack "$dir" STUB_LOG="$log" STACK_SKIP_GATES=audit
if [[ "$RC" == 0 ]] && grep -q "framework: laravel" <<<"$OUT" && grep -q "pint --test" "$log" && grep -q "phpstan analyse" "$log" && grep -q "artisan test APP_ENV=testing APP_KEY_SET=yes" "$log"; then
  ok "laravel: pint, phpstan and artisan test (APP_KEY generated, no .env needed)"
else bad "laravel stub case rc=$RC"; printf '%s\n' "$OUT" | tail -n 15 >&2; cat "$log" >&2; fi
rm -rf "$dir" "$log"
fi

# expo / react native: real node engine; expo CLI is a stub
dir="$(fixture_copy expo/good)"
mkdir -p "$dir/node_modules/.bin"
cp "${STUBS}/stub.sh" "$dir/node_modules/.bin/expo"
log="$(mktemp)"
run_stack "$dir" STUB_LOG="$log" STACK_SKIP_INSTALL=1 STACK_SKIP_GATES=audit
if [[ "$RC" == 0 ]] && grep -q "framework: expo" <<<"$OUT" && grep -qE "secrets-files +PASS" <<<"$OUT" && grep -q "expo export --platform android" "$log"; then
  ok "expo: secret-file check and expo export run"
else bad "expo good case rc=$RC"; printf '%s\n' "$OUT" | tail -n 15 >&2; fi
rm -rf "$dir" "$log"
dir="$(fixture_copy expo/bad)"
printf x >"$dir/release.keystore"   # created at test time: no key files are stored in this repository
run_stack "$dir" STACK_SKIP_INSTALL=1 STACK_SKIP_GATES=audit,expo-export
if [[ "$RC" == 1 ]] && grep -qE "secrets-files +FAIL" <<<"$OUT"; then ok "react native: tracked keystore and cleartext URL fail"; else bad "expo bad case rc=$RC"; printf '%s\n' "$OUT" | tail -n 12 >&2; fi
rm -rf "$dir"

# Userinfo must not make an untrusted cleartext host look like localhost.
dir="$(fixture_copy expo/good)"
printf 'export const api = "http://localhost@evil.example/api";\n' >"$dir/src/config.js"
if (cd "$dir" && SOURCE_ROOTS=src/ node "${SKILL}/scripts/stacks/tools/check-tracked-secrets.mjs") >/tmp/url-scan.out 2>&1; then
  bad "mobile secret scanner accepted http://localhost@evil.example"
else
  if grep -q "forbidden content" /tmp/url-scan.out; then
    ok "mobile secret scanner checks parsed URL host, not userinfo"
  else
    bad "unexpected URL scanner failure"; cat /tmp/url-scan.out >&2
  fi
fi
rm -rf "$dir" /tmp/url-scan.out

# rails: bundle and bin/rails are stubs; Gemfile.lock lists rails, rubocop, brakeman, bundler-audit
stub_case "rails: rubocop, brakeman, rails test, bundler-audit" rails/good pass "framework: rails" \
  "bundle install" "bundle exec rubocop" "bundle exec brakeman" "rails test" "bundle exec bundle-audit check" --
stub_case "rails: failing rubocop fails the run" rails/good fail "lint +FAIL" -- STUB_EXIT_BUNDLE=1

summary
