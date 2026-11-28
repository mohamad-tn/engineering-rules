# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Hardened local diagnostics and installers against repository-controlled shell execution, symlink writes, and credential exposure.
- Made local proof report incomplete gates accurately and reject untracked or ignored workflow inputs.
- Validated Python `-r` / `-c` requirements recursively and required exact version pins; corrected doctor path resolution and platform-specific tool installation.
- Tightened feature-flag date and URL checks, aligned CI workflow permissions, and improved Pages/site metadata validation.
- Clarified bilingual technology coverage and adoption guidance; corrected generated Arabic page title markup.
- Rejected inaccessible stack/doctor roots and invalid project maps; required gates with no result now fail instead of passing silently.
- Kept Node lockfile conflicts within the nearest project and passed install paths as arguments, including apostrophes and lockless libraries.
- Preserved Go tidy failures and rejected partial failed .NET audit results; CTest now fails when no tests run, and uv verifies its lock.
- Classified recognized HTTP 429 and rate-limit responses from network-dependent gates as NOT RUN without rerunning a command override; required gates still fail when they cannot run.
- Rejected untracked inputs in local proof, made SHA-lock selftests portable, corrected ShellCheck failures, and added command-level regression tests.
- Brought the Arabic secret-rotation runbook up to date with incident response and history-scan limitations.
- Disabled Git/Gitleaks color output for history scans and fail closed when a non-empty selected history is reported as zero commits scanned.
- Disabled unused Go module caching in the installer-only CI job, which has no root module manifest.

## [1.1.1] - 2026-11-26

### Fixed

- The portability check for `publish-prep` stays green after placeholders are filled, so CI does not fail on a published repository.
- PHP `audit` is N/A when the lockfile has no packages, and uses `composer audit --locked` otherwise, matching Composer 2.8+ on GitHub Actions.

## [1.1.0] - 2026-11-22

### Added

- Engines for Swift, C/C++ (CMake), Terraform/OpenTofu and Docker (hadolint), with real-toolchain tests for four of them.
- `install.sh --update`: refreshes scripts and workflows, keeps your edits (`.new` files), records a manifest.
- `--json` for `stack-gates.sh` and `local-proof.sh`, `--quiet` for `stack-gates.sh`, `references/fixing-failures.md`.
- Legacy-repository support: `DOCS_LINT_SCOPE=changed` (default), `SECRET_SCAN_FROM`, default-branch detection (`master`).
- Context budget test and a rule-completeness test; `docs/context-budget.md`, `llms.txt`, `llms-full.txt`.
- Claude Code plugin marketplace manifests, `CITATION.cff`, a bilingual static site with structured data, evals.
- Portability: bash 3.2 guard with Homebrew re-exec, BSD `sed`, GNU-free `timeout` handling, Windows `timeout.exe` safe, paths with spaces.

### Changed

- Rust `format` and `lint` gates are NOT RUN when `rustfmt` or `clippy` is missing, instead of failing the run.
- .NET fixtures target the current stable SDK (`net10.0`).
- README (English and Arabic) states clearly that core gates run in any repository and any language, even without a stack engine, and that Flutter/Java CI jobs are experimental.
- The static `publish-prep` check stays green after placeholders are filled, so CI does not fail on a published repository.
- Repository CI installs the current stable .NET SDK (`10.0.x`) to match the fixtures.
- README names the maintainer and points questions to GitHub Discussions.
- Explicit environment variables now always win over `.github/engineering-rules.env`.
- A Node library without a lockfile gets a warning instead of a failure; "no build script" is N/A.
- Sample, docs and fixture folders are not detected as projects (`STACK_INCLUDE_SAMPLES=1` to include them).
- Python: a project's own `mypy` file list is respected.

## [1.0.0] - 2026-11-15

### Added

- Universal rules file (`AGENTS.md`), pull-request template, CODEOWNERS, ADR and runbook templates.
- Core gates: secret scan (full history), docs-check, dependency-bot config check, policy gates, feature-flag expiry, PR size.
- Stack gates with auto-detection and monorepo support for Node, React, Vue, Angular, Svelte, NestJS, Next.js,
  React Native and Expo, .NET, PHP and Laravel, Flutter and Dart, Python and Django, Java and Spring, Go, Rust, Ruby and Rails.
- Required-gate policy: SKIP and NOT RUN fail the gates you require.
- Profiles: `lite`, `standard`, `strict`.
- One-command installer (`install.sh`), `doctor.sh`, and bridge files for Claude, Cursor, Copilot, Gemini and Windsurf.
- `local-proof.sh` for proof without paid CI; `ci-local.sh`, `continuity-check.sh`, `sync-rules-file.sh`.
- Per-stack GitHub Actions workflows and opt-in tool configs.
- Optional domain add-on for location, multi-country and marketplace products.
- Arabic edition of the skill and README.
- Test suites (core, stacks, installer, demo, static) and a before/after demo.
