#!/usr/bin/env bash
# shellcheck shell=bash
# C and C++ engine (CMake projects).

run_cpp() {
  have cmake || { notrun deps "cmake is not installed"; return 0; }
  local bdir
  bdir="${STACK_CPP_BUILD_DIR:-$(mktemp -d)/build}"
  echo "  cmake: $(cmake --version | head -n 1 | cut -d' ' -f3)   build dir: ${bdir}"

  gate_net deps -- cmake -S . -B "$bdir" -DCMAKE_BUILD_TYPE=Release

  if [[ -f .clang-format ]] && have clang-format; then
    gate format -- bash "${STACK_TOOLS_DIR}/cpp-format-check.sh"
  elif [[ -f .clang-format ]]; then
    notrun format "clang-format is not installed"
  else
    skip format "no .clang-format"
  fi

  if have cppcheck; then
    gate lint -- cppcheck --error-exitcode=1 --enable=warning,portability --quiet --inline-suppr --suppress=missingIncludeSystem -i build -i third_party -i vendor .
  else
    skip lint "cppcheck is not installed"
  fi
  na types "covered by the compiler and cppcheck"

  gate build -- cmake --build "$bdir" --parallel
  if grep -rqsE 'enable_testing|add_test' --include=CMakeLists.txt --include='*.cmake' .; then
    gate test -- ctest --test-dir "$bdir" --output-on-failure
  else
    skip test "no tests registered with CTest (enable_testing / add_test)"
  fi
  na audit "no standard dependency audit tool for C/C++; rely on your dependency manager"
}
