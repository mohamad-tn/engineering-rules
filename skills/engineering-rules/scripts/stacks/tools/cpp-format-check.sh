#!/usr/bin/env bash
# Fails when clang-format would change a C/C++ source file. Uses the project's own
# .clang-format. Skips build directories and vendored code.
set -uo pipefail
files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(find . \( -name build -o -name 'build-*' -o -name third_party -o -name vendor -o -name .git -o -name node_modules \) -prune -o \
  -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.h' -o -name '*.hh' -o -name '*.hpp' -o -name '*.hxx' \) -print0)
((${#files[@]})) || { echo "no C/C++ sources found"; exit 0; }
clang-format --dry-run --Werror "${files[@]}"
