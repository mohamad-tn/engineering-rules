#!/usr/bin/env bash
# shellcheck shell=bash
# Flutter / Dart engine.

run_flutter() {
  local tool=dart
  if grep -qE '^\s*flutter:|sdk:\s*flutter' pubspec.yaml; then tool=flutter; fi
  have "$tool" || { notrun deps "${tool} is not installed"; return 0; }
  echo "  framework: ${tool}"

  gate_net deps -- bash -c "${tool} pub get && { [ ! -f pubspec.lock ] || git diff --exit-code -- pubspec.lock; }"
  if [[ "$tool" == "flutter" ]] && ! git ls-files --error-unmatch pubspec.lock >/dev/null 2>&1; then
    warn lockfile "pubspec.lock is not committed: commit it for apps"
  fi

  gate format -- dart format --output=none --set-exit-if-changed .

  if [[ "$tool" == "flutter" ]]; then
    gate lint -- flutter analyze
  else
    gate lint -- dart analyze --fatal-infos
  fi
  na types "covered by the analyzer (lint)"

  if [[ -n "$(find test -name '*_test.dart' -print -quit 2>/dev/null)" ]]; then
    if [[ "$tool" == "flutter" ]]; then gate test -- flutter test; else gate test -- dart test; fi
  else
    skip test "no test/*_test.dart files"
  fi

  if [[ -n "${STACK_FLUTTER_BUILD:-}" ]]; then
    # shellcheck disable=SC2086
    gate build -- flutter build ${STACK_FLUTTER_BUILD}
  else
    skip build "set STACK_FLUTTER_BUILD (for example \"apk --debug\") to build"
  fi

  na audit "pub has no official audit tool; rely on your dependency bot"
  if [[ -d android || -d ios ]]; then
    gate secrets-files -- env SOURCE_ROOTS="lib/" node "${STACK_TOOLS_DIR}/check-tracked-secrets.mjs"
  fi
}
