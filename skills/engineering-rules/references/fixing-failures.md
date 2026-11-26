# Fixing failures

What to do when a gate fails. Read the message first: every gate prints the file, the rule
or the command that failed. Never "fix" a failure by weakening the gate.

## Core gates

| Gate and message | Cause | Fix |
|---|---|---|
| Secret scan: `project-dotenv-file`, `project-signing-key-file`, a default gitleaks rule | A secret or a secret-like file is in git history | **Rotate the secret first.** If the branch is not shared, rewrite it so the commit disappears (`git reset --soft`, recommit without the file). Add the file to `.gitignore` and commit a `.env.example` with names only. Never add `.gitleaksignore`. |
| Secret scan: `Shallow clone` | CI fetched only the last commit | `fetch-depth: 0` (GitHub), `GIT_DEPTH: 0` (GitLab) |
| Secret scan fails on old history in an existing repository | Old secrets were committed long ago | Rotate them, record an ADR, then set `SECRET_SCAN_FROM=<adoption commit>` in `.github/engineering-rules.env`. The scan then covers newer commits only, and says so loudly. |
| docs-check: `code changed under "<glob>" without a change in: ...` | Code changed, its docs did not | Update one of the listed docs in the same pull request. If no doc is affected, add the label `no-docs-needed` with a written reason. |
| docs-check: `CHANGELOG.md has no entry` | A `feat` or `fix` pull request without a changelog line | Add a line under `Unreleased`. Titles of type `chore`, `ci`, `test` are exempt. |
| docs-check: markdown lint | A changed markdown file breaks a rule | Fix the file (the message names rule and line). Old files are not linted in profiles `lite` and `standard`. |
| docs-check: required doc missing | A file from `required-docs.json` is absent | Create it, or remove it from the list with an ADR. |
| Policy gates: `currency code literal`, `region code`, `time-zone id`, `dial prefix`, `named place` | Business configuration is typed into code | Move the value to configuration (environment, settings table). If it is a false positive (a test, a seed), add the path pattern to `.github/policy/country-literals.json`. |
| Policy gates: `... is a prerelease` | A beta, rc or preview dependency | Use a stable version, or write an ADR and add the package to `.github/policy/prerelease-allow.json`. |
| Flag expiry | A feature flag is past its `expiresOn` date | Remove the flag and its code, or extend the date and write why. |
| PR size: `changes N lines, above 800` | The pull request is too large | Split it. Move generated or pasted data out of the change. If it cannot be split, add `pr-size-reason` and explain in the description. |
| Renovate config | `renovate.json` is invalid or does not extend the preset | Run `bash .github/scripts/renovate-config-check.sh`; the validator names the key. |

## Stack gates (all stacks)

| Result | Meaning | Fix |
|---|---|---|
| `deps` FAIL: no lockfile | An application without a lockfile | Commit it (`package-lock.json`, `Cargo.lock`, `composer.lock`, `Gemfile.lock`, `pubspec.lock`, `uv.lock`...). |
| `deps` FAIL: install failed | The locked install does not work | Run the same command locally (the output shows it). Usually the lockfile is out of sync with the manifest: regenerate and commit it. |
| `test` SKIP: no tests | Required gate has nothing to run | Add tests, or set `STACK_REQUIRE` to drop `test` with an ADR. A project with no tests should say so. |
| `NOT RUN` | A tool or the network is missing | Install the tool (the message names it). In CI add the setup step; locally use the package manager. |
| `format` FAIL | Code is not formatted | Run the formatter (`prettier --write`, `gofmt -w`, `dotnet format`, `cargo fmt`, `dart format .`, `ruff format`, `pint`, `tofu fmt`). |
| `lint` FAIL | The linter or analyzer found issues | Fix them. A rule you disagree with is changed in the tool's own config, in a reviewed pull request. |
| `audit` FAIL | A known-vulnerable dependency | Update it. If no fix exists, record an ADR with the mitigation and add the advisory exception in the tool's own file. |
| `bundle-scan` FAIL (Next.js) | The private backend host is in the client bundle | Move the call behind a server route; keep the host in a server-only variable. |
| `secrets-files` FAIL (mobile) | A keystore, credentials file or `http://` URL is tracked | Remove it, rotate the key, use a secret store. |
| `migrations` FAIL (Django) | A model changed without a migration | `python manage.py makemigrations` and commit. |
| `mod-tidy` FAIL (Go) | `go.mod` or `go.sum` is not tidy | `go mod tidy` and commit. |
| `pinned` FAIL (Python) | A requirement without `==` | Pin it (`pip freeze` or a lock tool). |

## For an AI agent

1. Run `bash .github/scripts/local-proof.sh --json` and read `gates[].status`.
2. For each `FAIL`, run that gate alone (`references/local-proof.md` lists the commands) and read its output.
3. Fix the cause. Do not edit a gate, a profile, an exception label or the pins to make it pass.
4. If a fix needs a decision (a new dependency, a rule deviation, a larger pull request), write an open question or an ADR and stop.
5. Re-run until every row is `PASS` (or `NA`). Paste the Markdown proof into the pull request.
