# C and C++ (CMake)

Engine: `scripts/stacks/cpp.sh`. Detects a `CMakeLists.txt`; nested CMake projects belong to the one above them.

| Gate | Runs |
|---|---|
| deps | `cmake -S . -B <temp dir>` (configure; your repository stays clean) |
| format | `clang-format --dry-run --Werror` when a `.clang-format` file exists |
| lint | `cppcheck` (warnings and portability, errors fail) when installed |
| build | `cmake --build <dir> --parallel` |
| test | `ctest --output-on-failure` when tests are registered (`enable_testing`, `add_test`) |

`types` and `audit` are N/A: the compiler is the type checker and C/C++ has no standard audit tool.

## Recommended setup

- Commit a `.clang-format`; add `-Wall -Wextra` (and `-Werror` in CI) to your targets.
- Register tests with CTest so the `test` gate has something to run.
- Pin dependencies with your package manager (vcpkg, Conan) and commit its lock or manifest.

## CI

`templates/stacks/cpp/ci.yml` installs `cmake`, `cppcheck` and `clang-format` on an Ubuntu runner.
