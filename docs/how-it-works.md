# How it works

## The pieces

| Piece | Where | Job |
|---|---|---|
| Rules file | `AGENTS.md` (from `templates/AGENTS.md`) | the one short file humans and AI assistants follow |
| Core gates | `scripts/*.sh`, `scripts/*.mjs`, `templates/docs-check.*`, `templates/pr-size-check.sh` | fail a pull request for secrets, missing docs, hard-coded configuration, prerelease dependencies, expired feature flags, oversized changes |
| Stack gates | `scripts/stack-gates.sh`, `scripts/stacks/<engine>.sh` | detect the stacks and run install, format, lint, types, tests, build, audit for each |
| Proof | `scripts/local-proof.sh` | run everything and print a block for the pull request |
| CI | `templates/project-gates.yml`, `templates/stacks/*/ci.yml` | call the same scripts on GitHub Actions |
| Setup | `scripts/install.sh`, `scripts/doctor.sh` | one command to adopt, one to check |
| Skill | `SKILL.md`, `references/` | tells an AI assistant how to adopt and follow it |

## The loop

```text
roadmap -> phase -> task (about one pull request, about 400 lines)
        -> gates (CI, or local-proof.sh with the output pasted in the pull request)
        -> human review -> human merge -> phase gate at the end of each phase
```

## Design decisions

**Scripts, not a service.** A gate is a script with an exit code. That is why it runs in any CI
and on a laptop, and why there is nothing to host, sign up for, or trust with your code.

**One result vocabulary.** Every stack gate ends as PASS, FAIL, SKIP, NOT RUN or N/A.
The runner turns SKIP and NOT RUN into a failure for the gates you require (`STACK_REQUIRE`),
so a missing tool or a missing test suite cannot masquerade as success. N/A is reserved for things
that do not exist in a stack (PHP has no build step).

**Auto-detection, explicit override.** Stacks are found from marker files (`package.json`, `go.mod`,
`Cargo.toml`, `*.csproj`, `composer.json`, `pubspec.yaml`, `pyproject.toml`, `pom.xml`, `Gemfile`...).
You can list projects explicitly in `.github/engineering-rules.stacks` and replace any gate's command with
`STACK_CMD_<GATE>`.

**Pinned, verified tools.** Tools the gates download (gitleaks, lychee, linters run through npx) are pinned
in `.github/tool-pins.env`; downloaded binaries are verified against a SHA-256 before they run.
GitHub Actions in the templates are pinned to commit SHAs.

**Secrets are rotated, never ignored.** The secret scan reads the full git history, redacts its output,
and refuses a `.gitleaksignore` file.

**Exceptions are visible.** `no-docs-needed` and `pr-size-reason` are labels with a written reason in the
pull request; the reviewer accepts or rejects them.

**Honest status.** Rules are Enforced, Implemented, Review, Ops or Planned. Planned never reads as enforced.

## What runs your code

Stack gates run **your project's own** commands (`npm test`, `go test`, `cargo build`...). Treat a pull request
from an untrusted fork like any other untrusted code in CI: the provided workflows use `pull_request` (not
`pull_request_target`), read-only permissions and `persist-credentials: false`.

## Delivery continuity

When hosted CI is unavailable there are four levels: hosted, self-hosted runner, replaying the workflow
files locally with `act`, and fully offline. The gates and the review never relax; assistants still never merge.
Details: [`continuity.md`](../skills/engineering-rules/references/continuity.md).
