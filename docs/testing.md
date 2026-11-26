# Testing

```bash
bash tests/run-all.sh              # everything
bash tests/run-all.sh stacks       # one suite: core | stacks | installer | portability | adoption | demo | parity | context | static
```

## Suites

| Suite | File | What it checks |
|---|---|---|
| core | `skills/engineering-rules/scripts/selftest.sh` | PR size, docs-check, policy gates, flag expiry, SHA-256 lock, offline CI event: each passes on good input and fails on bad |
| stacks | `tests/test-stacks.sh`, `tests/test-quality.py`, `tests/test-proof-quality.py` | engine fixtures, required results, overrides, monorepos, path handling, audit failure propagation, and partial-proof semantics; command-level stubs do not replace real SDK tests |
| installer | `tests/test-installer.sh` | installing into repositories, never overwriting, options, `doctor.sh`, and a full `local-proof.sh` in an adopted repository |
| demo | `tests/test-demo.sh` | the before/after demo fails five gates for the stated reasons, then passes all |
| portability | `tests/test-portability.sh` | macOS (bash 3.2, BSD sed, no GNU timeout) and Git Bash differences, simulated with shims; paths with spaces |
| adoption | `tests/test-adoption.sh` | legacy repositories (old docs, old secrets in history, a `master` branch) and the `--json` and `--quiet` outputs |
| context | `tests/test-context.sh` | the context budget, and every binding rule stated in the always-loaded `AGENTS.md` |
| parity | `tests/test-parity.sh` | the Arabic edition has the same files, byte-identical scripts, and the same sections, tables and code blocks as the English one |
| static | `tests/test-static.sh` | shellcheck, `bash -n`, `node --check`, JSON and YAML, actionlint, markdownlint, internal links, no secret-looking strings or key files |

## Which toolchains run for real

"Real" means the actual compiler, package manager and linters ran in the test environment.
"Stubbed" means a stand-in program recorded the commands the engine issued (order, arguments,
failure propagation); the real tool was not run there.

| Stack | Fixture | Result in the author's test environment |
|---|---|---|
| Go | `go/good`, `go/bad` | real |
| Rust | `rust/good`, `rust/bad` | real cargo; rustfmt and clippy when installed, otherwise those gates are NOT RUN |
| Python | `python/good`, `bad`, `unpinned` | real (pip, pytest, ruff) |
| Ruby | `ruby/good`, `ruby/bad` | real (Bundler); RuboCop and Rails not installed |
| .NET | `dotnet/good`, `dotnet/bad` | real SDK 10 (`net10.0`); restore from a local source because NuGet was not reachable |
| PHP / Laravel | `php/good`, `php/bad`, `laravel/good` | real PHP and Composer; Pint, PHPStan and `artisan` are stubs |
| Node | `node/good`, `bad`, `nolock` | real |
| React (Vite) | `react/good` | real install and build |
| Next.js | `nextjs/good` | real install and build; the audit gate reported real advisories |
| React Native, Expo | `expo/good`, `expo/bad` | real Node engine and secret-file check; Expo CLI stubbed |
| C and C++ (CMake) | `cpp/good`, `cpp/bad` | real (cmake, g++, cppcheck, clang-format) |
| Terraform, OpenTofu | `terraform/good`, `terraform/bad` | real (OpenTofu) |
| Docker | `docker/good`, `docker/bad` | real (hadolint); `docker build` not run |
| Swift | `swift/good` | stubbed Swift toolchain |
| Flutter | `flutter/good` | stubbed SDK |
| Java (Maven, Gradle) | `java-maven/good`, `java-gradle/good` | stubbed wrappers |
| Rails | `rails/good` | stubbed Bundler and `bin/rails` |

The repository's own CI (`.github/workflows/ci.yml`) runs the same suites on GitHub's runners, where most
toolchains are preinstalled, and adds jobs that exercise Flutter and Java with their real toolchains.
Those two jobs are marked experimental until they have been green on GitHub for a while.

## Add a fixture

A good project that passes and a bad one that fails, under `tests/fixtures/<stack>/`, plus a case in
`tests/test-stacks.sh`. Keep fixtures tiny and dependency-free where you can, so the suite stays fast and offline-friendly.
Do not put secrets, key files or `.env` files in fixtures: the static suite will fail the build.
