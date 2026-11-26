# Stack gates

One command runs the right checks for whatever your repository contains:

```bash
bash .github/scripts/stack-gates.sh          # every stack it finds
bash .github/scripts/stack-gates.sh --list   # just show what it detects
```

It detects the stacks, runs the standard gates for each, and prints one row per gate.
Monorepos are handled: a `web/` (Next.js), an `api/` (Go) and a `mobile/` (Expo) folder in
one repository each get their own run.

## The gates

| Gate | Question it answers |
|---|---|
| `deps` | Does a clean, locked install work? (lockfile committed, frozen install) |
| `format` | Is the code formatted? |
| `lint` | Does the linter or analyzer pass? |
| `types` | Does the type checker or static analyzer pass? |
| `test` | Do the tests pass? |
| `build` | Does the production build succeed? |
| `audit` | Are there known vulnerabilities in the dependencies? |
| extras | Stack-specific: `bundle-scan`, `secrets-files`, `migrations`, `mod-tidy`, `syntax`, `pinned`... |

## Results

| Result | Meaning |
|---|---|
| PASS | ran and succeeded |
| FAIL | ran and failed (the last lines of the log are printed) |
| SKIP | nothing to run (no script, no config) |
| NOT RUN | applies, but a tool or the network is missing |
| N/A | does not apply to this stack (PHP has no build step) |
| WARN | advice only |

**Required gates.** `STACK_REQUIRE` (default `deps,test,build`) lists the gates that must
PASS. For those, SKIP and NOT RUN count as a failure: "nothing ran" never looks green. A
project with no tests fails `test` until it has some. Profiles change the list:
`lite` requires `deps,test`; `strict` adds `format,lint,types,audit`.

## Configure

Put values in `.github/engineering-rules.env` (the installer writes it from a profile):

| Variable | Effect |
|---|---|
| `STACK_REQUIRE` | gates that must pass |
| `STACK_STRICT=1` | also require format, lint, types, audit |
| `STACK_CMD_<GATE>` | replace a gate's command: `STACK_CMD_TEST="make test"` |
| `STACK_SKIP_GATES` | switch gates off on purpose (they leave the required list) |
| `STACK_EXCLUDE` | path prefixes to ignore, for example `examples/ docs/site` |
| `STACK_FAST=1` | skip `build`, `audit`, `e2e` (a quick loop while coding) |
| `AUDIT_LEVEL` | minimum severity that fails an audit |

An explicit project list in `.github/engineering-rules.stacks` (`node:web`, `go:api`) replaces detection.

## Supported stacks and how well each one is tested

| Stack | Frameworks | Reference | Tested with |
|---|---|---|---|
| node | Node.js, React, Vue, Angular, Svelte, NestJS, Express, Vite | [node.md](node.md) | real npm, real React/Vite project |
| nextjs | Next.js | [nextjs.md](nextjs.md) | real Next.js build; the audit gate caught real advisories |
| react-native | React Native, Expo | [react-native.md](react-native.md) | real node engine and secret-file check; Expo CLI stubbed |
| dotnet | ASP.NET Core, console, libraries | [dotnet.md](dotnet.md) | real .NET SDK (restore from a local source) |
| php | Laravel, Symfony, Composer packages | [laravel.md](laravel.md) | real PHP and Composer; Pint, PHPStan and `artisan` stubbed |
| flutter | Flutter, Dart | [flutter.md](flutter.md) | command-level tests with stubbed SDK; real run happens in the repository CI matrix |
| python | Django, FastAPI, Flask, libraries | [python.md](python.md) | real pip, pytest, ruff |
| java | Spring Boot, Maven, Gradle, Kotlin | [java.md](java.md) | command-level tests with stubbed build tools |
| go | Go modules | [go.md](go.md) | real Go toolchain |
| rust | Cargo | [rust.md](rust.md) | real cargo, rustfmt, clippy |
| ruby | Rails, gems | [ruby.md](ruby.md) | real Ruby and Bundler; Rails and RuboCop stubbed |
| cpp | C and C++ (CMake) | [cpp.md](cpp.md) | real cmake, g++, cppcheck, clang-format |
| terraform | Terraform, OpenTofu | [terraform.md](terraform.md) | real OpenTofu |
| docker | Dockerfiles | [docker.md](docker.md) | real hadolint |
| swift | Swift Package Manager | [swift.md](swift.md) | command-level tests with a stubbed toolchain |

"Stubbed" means the engine's commands, order and failure handling are verified, but the real
tool was not run in the test environment. See `docs/testing.md` in the repository for the
exact matrix and how to run it yourself.

## Add a stack

See `CONTRIBUTING.md`: an engine is one file in `scripts/stacks/<name>.sh`, one workflow in
`templates/stacks/<name>/ci.yml`, one reference here, and a good and a bad fixture in `tests/`.
