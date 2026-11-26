<div align="center">

<img src="assets/banner.svg" alt="engineering-rules: guardrails for fast (and AI-written) code" width="100%">

[![CI](https://github.com/mohamad-tn/engineering-rules/actions/workflows/ci.yml/badge.svg)](https://github.com/mohamad-tn/engineering-rules/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Stacks](https://img.shields.io/badge/stacks-Node%20%7C%20Next.js%20%7C%20React%20%7C%20React%20Native%20%7C%20.NET%20%7C%20Laravel%20%7C%20Flutter%20%7C%20Python%20%7C%20Java%20%7C%20Go%20%7C%20Rust%20%7C%20Ruby-3fb950.svg)](skills/engineering-rules/references/stacks/README.md)
[![No paid CI needed](https://img.shields.io/badge/paid%20CI-not%20required-79c0ff.svg)](docs/ci-providers.md)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**English** · [العربية](README.ar.md) · [Website](https://mohamad-tn.github.io/engineering-rules/)

</div>

# engineering-rules

**Guardrails for fast code, and for code written by AI.** One command adds a small set of
engineering rules and real, automated checks (*gates*) to any repository. Every pull request
carries proof that the checks passed, on GitHub Actions or on your own laptop. It works with
Claude Code, Cursor, Codex, Copilot, Gemini and with plain human teams.

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project
```

It detects your stack (Node, Next.js, React, React Native, Vue, Angular, .NET, Laravel, Flutter,
Python, Java, Go, Rust, Ruby, Swift, C/C++, Terraform, Docker), sets up the checks, and never overwrites a file you already have.
The core gates — secrets, docs, pull-request size, policy — run in every git repository, including
one whose language has no stack engine yet. A missing engine is never reported as a green stack run.

---

## The problem

Writing code has never been faster. Reviewing it has not. A coding assistant, or a rushed
Friday, produces a 1,300-line pull request that "works on my machine", and the usual
failures slip through:

| What goes wrong | Why it hurts |
|---|---|
| A `.env` file or key is committed | The secret is in git history forever; rotating it is now an incident |
| Currency, time zone, hosts and tax rates are typed into code | Every new market or environment needs a code change and a release |
| One pull request changes 1,300 lines | Nobody reviews it properly; bugs ride along |
| Code changes, docs and changelog do not | The docs lie within a month |
| A "beta" dependency sneaks in, or there is no lockfile | Builds differ between machines; you cannot reproduce a bug |
| Tests were skipped "just this once" | Green means nothing |
| Feature flags are never removed | Dead code paths pile up |
| CI minutes ran out, or CI is down | Work stops, or people merge without checks |
| An AI assistant "finishes" the task and says it works | Nothing proves it |

`engineering-rules` turns each of these into a check that fails loudly, and a habit that is
cheap to follow.

## What it is

- **A short rules file** (`AGENTS.md`) that humans and AI assistants follow the same way.
- **Gates**: scripts that fail a pull request for the problems above. They are plain shell
  and Node, so they run in any CI and on your machine.
- **Stack gates** for Node, React, Vue, Angular, Next.js, React Native, .NET, Laravel, Flutter, Python, Java, Go, Rust, Ruby, Swift, C/C++, Terraform and Docker: lockfile, install, format, lint, types, tests, build, audit. If your language is not in this list, the core gates still run.
- **Proof**: `local-proof.sh` runs everything and prints a block you paste into the pull
  request. No paid CI required.
- **An Agent Skill** (`SKILL.md`) so an AI assistant knows how to adopt and follow all of this.

```mermaid
flowchart LR
    A[Developer or AI assistant] -->|small task| B[Branch]
    B --> C{Gates}
    C -->|secret scan| G[Proof block]
    C -->|docs-check| G
    C -->|policy + flags| G
    C -->|PR size| G
    C -->|stack gates| G
    G -->|pasted in the PR, or green CI| H[Human review]
    H -->|only a human merges| I[main]
```

## See it work in 60 seconds

The same checkout feature, written twice. First as a typical fast pull request:

<img src="assets/demo-before.svg" alt="Five gates fail on the first version of the pull request" width="100%">

Then rewritten to the rules:

<img src="assets/demo-after.svg" alt="All gates pass on the rewritten version" width="100%">

This is not a mock-up. It is the real output of [`examples/shop-api/run-demo.sh`](examples/shop-api/run-demo.sh)
(saved in [`output-before.txt`](examples/shop-api/output-before.txt) and
[`output-after.txt`](examples/shop-api/output-after.txt)). Run it yourself:

```bash
bash examples/shop-api/run-demo.sh
```

## Before and after: your code

Everything below comes from the demo. The "before" is what a fast first draft often looks like.

### 1. Configuration typed into code

```diff
- const CURRENCY = "USD";
- const TIMEZONE = "Europe/Berlin";
- const TAX_RATE = 0.19;
+ const { loadConfig } = require("./config");   // reads the environment; a missing value is an error
```

The **policy gate** fails the first version: `currency code literal "USD"`,
`time-zone id literal "Europe/Berlin"`. A new market becomes a configuration change, not a release.

### 2. A network call that can hang, with a secret in the source

```diff
- const response = await fetch("https://api.example.com/charge", {
-   headers: { Authorization: "Bearer live_..." },
-   body: JSON.stringify({ total, currency: CURRENCY }),
- });
+ const response = await fetch("https://api.example.com/charge", {
+   headers: { Authorization: `Bearer ${config.apiKey}` },
+   body: JSON.stringify({ total: orderTotal(items, config.taxRate), currency: config.currency }),
+   signal: AbortSignal.timeout(config.timeoutMs),   // cannot hang
+ });
```

The rules file says every network call has a timeout and non-idempotent calls are never retried.
Reviewers and assistants check it; the *secret* part is caught by the secret scan (next).

### 3. A committed `.env`

```diff
- DATABASE_URL=postgres://admin:...@db.internal.example/shop     # .env, tracked in git
- PAYMENT_API_KEY=...
+ DATABASE_URL=                                                  # .env.example: names, never values
+ PAYMENT_API_KEY=
```

The **secret scan** reads the whole git history and fails with the rule name and the file.
The fix is to rotate the key *and* rewrite the branch before it is shared; a later "delete" commit is not enough.

### 4. One giant pull request

```text
This pull request changes 1331 lines, above 800.
Split it, or add the label pr-size-reason with a written reason.
```

Lockfiles, snapshots and generated code do not count. A 1,300-line paste of data was the problem here; it does not belong in the change.

### 5. Code without docs

```text
docs-check: code changed under "src/**" without a change in: docs/features/**, CHANGELOG.md
docs-check: CHANGELOG.md has no entry and the pull-request title type "feat" is not one of chore/ci/test
```

### 6. The pull request description

| Before | After |
|---|---|
| "feat: checkout. Works on my machine." | The [template](skills/engineering-rules/templates/PULL_REQUEST_TEMPLATE.md): summary, definition of done, risk and rollback, and a **proof block** with the commit, the date and PASS/FAIL per gate |

### What the stack gates catch

| Stack | An example of what fails |
|---|---|
| Node, React, Vue, Angular | no lockfile; failing `test`; `npm audit` finds a high-severity advisory |
| Next.js | the built client bundle contains your private API host |
| React Native, Expo, Flutter | a tracked keystore or `key.properties`; a cleartext `http://` URL; a drifting `pubspec.lock` |
| .NET | a warning (warnings are errors); a vulnerable NuGet package |
| Laravel, PHP | a syntax error; Pint or PHPStan findings; `composer audit` advisories |
| Python, Django | unpinned requirements; a model change without a migration |
| Java, Spring | failing `verify`; no Maven or Gradle wrapper (warning) |
| Go | `go.mod` not tidy; unformatted code; `go vet` findings |
| Rust | a clippy warning; a binary without `Cargo.lock` |
| Ruby, Rails | RuboCop and Brakeman findings; `bundler-audit` advisories |

On the Next.js test project in this repository the audit gate genuinely reports high-severity
advisories of its deliberately old Next.js version.

## Quick start

### Option A: one command (any repository)

```bash
git clone https://github.com/mohamad-tn/engineering-rules.git
bash engineering-rules/skills/engineering-rules/scripts/install.sh --target ./my-project \
     --profile standard --org my-org --project my-project --owner my-handle
cd my-project
bash .github/scripts/doctor.sh        # checks the setup, tells you what is left
git add -A && git commit -m "chore: adopt engineering rules"
bash .github/scripts/local-proof.sh   # runs every gate; paste the output in your first pull request
```

Options: `--profile lite|standard|strict`, `--stack auto|none|node,go,...`,
`--layout single|member`, `--agents all|none|claude,cursor,...`, `--stack-configs`, `--dry-run`, `--force`.
Nothing is overwritten unless you pass `--force`.

### Option B: as an Agent Skill

Copy [`skills/engineering-rules`](skills/engineering-rules) into your assistant's skills folder
(for Claude Code: `.claude/skills/engineering-rules/` in a project or `~/.claude/skills/` for all projects),
then ask: *"Adopt the engineering rules in this repository."* The assistant reads
[`SKILL.md`](skills/engineering-rules/SKILL.md), runs the installer, fills the placeholders and runs the proof.
For tools that read `AGENTS.md` (Cursor, Codex, Copilot, Gemini and others) the installer also writes small bridge files.
The repository is also a Claude Code plugin marketplace, and its `skills/` folder can be installed with the open `skills` CLI:

```bash
# Claude Code plugin marketplace
/plugin marketplace add mohamad-tn/engineering-rules
/plugin install engineering-rules@engineering-rules

# or, with the open "skills" CLI
npx skills add mohamad-tn/engineering-rules --skill engineering-rules
```

### Option C: copy what you need

Every file stands alone. Take only `gitleaks.toml`, or only the PR-size script, or only `AGENTS.md`.

## Using it every day

| You are | You do |
|---|---|
| **A developer** | Work in small tasks. Before asking for review: `bash .github/scripts/local-proof.sh` and paste the output. Quick loop while coding: `bash .github/scripts/stack-gates.sh --fast`. |
| **An AI assistant** | Read `AGENTS.md`. Never merge. Run the proof. If a requirement is missing, write an open question instead of guessing. |
| **A reviewer** | Check the proof commit equals the PR head and every row is PASS (none NOT RUN). Accept or reject written exceptions. |
| **A maintainer** | Keep `AGENTS.md` and `docs/rules-compliance.md` honest: every rule is Enforced, Review, Ops or **Planned**. |

CI runs the same scripts: [`project-gates.yml`](skills/engineering-rules/templates/project-gates.yml)
for the core gates and one small workflow per stack in
[`templates/stacks/`](skills/engineering-rules/templates/stacks).

## What is inside

**Core gates** (every project): secret scan (full history, redacted, no ignore file) ·
docs-check (required docs, code-to-docs map, changelog, markdown lint, internal links) ·
dependency-bot config · policy gates (prerelease dependencies, hard-coded environment values) ·
feature-flag expiry · PR size.

**Stack gates** (per stack): `deps` · `format` · `lint` · `types` · `test` · `build` · `audit` · extras
such as `bundle-scan`, `secrets-files`, `migrations`, `mod-tidy`.

**Profiles**: `lite` (solo and prototypes: secrets, dependencies, tests) · `standard` (default) ·
`strict` (teams and public libraries: every gate, lower size limits).

**Also**: a rules file starter, PR template, CODEOWNERS, pre-commit hook, Renovate preset, ADR and
runbook templates, a phase-gate checklist, a delivery-continuity plan (what to do when CI is down),
bridge files for AI assistants, and an optional [domain add-on](skills/engineering-rules/references/domain-optional.md)
for location-based, multi-country and marketplace products.

## Works with any idea, not only one kind of product

The core is about how software is delivered, not what it does. It fits any software project,
in any language: core gates always run, and stack-specific install, lint, test and build gates
run when a matching engine exists. It has been shaped to fit:

| Project | Notes |
|---|---|
| SaaS and web apps | all gates; Next.js, React, Laravel, Django, Rails, .NET |
| Mobile apps | React Native, Expo, Flutter; keystore and cleartext checks |
| APIs and backends | .NET, Node, Go, Java, Python, Rust, PHP |
| Libraries and packages | `strict` profile; lockfile and audit gates |
| Internal tools, scripts, CLIs | `lite` profile |
| Content sites and marketing pages | docs-check, secret scan, size gate |
| Monorepos | every project found runs, each with its own stack |
| Location, multi-country, on-demand marketplaces | add the optional domain module; nothing else changes |

More in [`docs/project-types.md`](docs/project-types.md).

## How it works, and why it is built this way

- **Small core, optional adapters.** The universal rules fit on a page. Stacks and the domain module are separate files you load only if you need them.
- **Scripts, not a service.** Everything is shell and Node. No account, no server, no data leaves your machine. Tools it downloads are pinned and checksum-verified.
- **"Nothing ran" is never green.** Gates are PASS, FAIL, SKIP, NOT RUN or N/A. The ones you require fail when they did not actually run.
- **Honest status.** Every rule is marked Enforced, Review, Ops or **Planned** ([rules index](skills/engineering-rules/references/rules-index.md)).
- **Works without paid CI.** If hosted CI is off, run the same scripts locally and paste the proof; there is a four-level fallback plan ([continuity](skills/engineering-rules/references/continuity.md)).
- **Humans merge.** Assistants never do.

Read more: [`docs/how-it-works.md`](docs/how-it-works.md).

## Built for AI agents

The skill is deliberately small, so an agent receives **every** rule without filling its context window.

| What | Size (estimated) | When it is loaded |
|---|---|---|
| Skill name and description | about 250 tokens | always |
| `SKILL.md` | about 1.6k tokens, 80 lines | when the skill triggers |
| `AGENTS.md` (the complete binding rules) | about 1.5k tokens, 90 lines | every session in an adopting repository |
| One reference file | at most 2.6k tokens | only when the task needs it |
| Everything essential in one file | about 7.7k tokens ([`llms-full.txt`](llms-full.txt)) | for tools that fetch a single URL |

A test (`tests/test-context.sh`) enforces these budgets and fails if a binding rule is missing from the always-loaded
`AGENTS.md`. Results are machine-readable too: `local-proof.sh --json` and `stack-gates.sh --json`, and
[`fixing-failures.md`](skills/engineering-rules/references/fixing-failures.md) tells an agent how to repair each failure
without weakening a gate. Token counts are estimates; Arabic uses roughly twice as many tokens per word.

## Upgrading

New version of the skill? Refresh the scripts and workflows without losing your edits:

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project --update
```

Files you changed are kept and the new version is written next to them as `.new`. Your `AGENTS.md`, docs and configs are never touched.

## How it compares

| Tool | What it does well | What this adds |
|---|---|---|
| pre-commit, Husky | run checks on one machine before a commit | the same checks in CI and as pasted proof, plus rules for AI agents |
| MegaLinter, Super-Linter | lint many languages in CI | delivery rules (secret history, docs with code, PR size, flag expiry), a required-gate policy, proof without CI |
| Danger, reviewdog | comment on pull requests | failing checks you can also run locally, in any CI |
| SonarQube, Snyk, Dependabot | deep code quality and vulnerability analysis | a small floor that runs your ecosystem's audit; use them together |
| A rules file alone (`AGENTS.md`, `CLAUDE.md`) | tells an agent what to do | gates that check the agent really did it |

## Tested, not just written

```bash
bash tests/run-all.sh
```

| Suite | What it proves |
|---|---|
| core | each gate passes on good input and fails on bad input |
| stacks | 46 cases: real Go, Rust, Python, Ruby, .NET, PHP, Node, React (Vite), Next.js, C++, Terraform and Docker projects, good and bad; command-level tests for Flutter, Swift, Maven, Gradle, Laravel tooling, Expo and Rails |
| installer | 42 cases: install, idempotence, options, doctor, a full local proof in an adopted repository (both languages), and safe updates |
| demo | the before/after demo keeps telling the truth |
| parity | the Arabic edition mirrors the English one: same files, byte-identical scripts, same sections, tables and code blocks |
| portability | macOS (bash 3.2, BSD sed, no GNU timeout) and Git Bash differences, simulated; paths with spaces |
| adoption | legacy repositories (old docs, old secrets, `master` branch) and `--json` output for agents |
| context | the context budget, and every binding rule stated in the always-loaded `AGENTS.md` |
| static | shellcheck, workflow lint, JSON/YAML, markdown lint, links, no secret-looking strings |

Some toolchains cannot run everywhere; the exact matrix, and which parts run for real, is in
[`docs/testing.md`](docs/testing.md). The repository's own CI runs the suites on GitHub.

## FAQ

**Do I need an AI assistant to use it?** No. It is useful for any team; the assistant files and the skill are extras.

**Will it slow me down?** The loop is: small task, one command, paste proof. The gates are what you would otherwise discover in review or in production. Use `--fast` while coding and the `lite` profile for prototypes.

**My repository is a mess. Where do I start?** Start with `lite`, fix what fails, then move to `standard`. See [`docs/adoption-guide.md`](docs/adoption-guide.md).

**Can I use GitLab, Bitbucket or Jenkins?** Yes. The gates are scripts; call them from any pipeline ([`docs/ci-providers.md`](docs/ci-providers.md)).

**Windows?** Use WSL or Git Bash. The scripts are bash.

**Is it opinionated?** About the process, yes: small pull requests, secrets, docs with code, honest status. Every threshold and gate is configurable, and an exception is a label with a written reason.

More questions: [`docs/faq.md`](docs/faq.md).

## Roadmap and honest limits

- More engines (Kotlin Multiplatform, Elixir, Scala, Deno, Bazel) are welcome: see [CONTRIBUTING](CONTRIBUTING.md#add-a-stack).
- Architecture tests, migration linting, container build proofs and time-zone matrices are **Planned**: the guide describes them but they depend on your code and database, so they are not turnkey gates.
- Flutter and Java gates are verified at the command level here, and the repository CI has jobs that run them with real toolchains. Those jobs are marked experimental until they stay green on GitHub.
- If an optional tool is missing (for example `rustfmt` or `clippy`), that gate is reported as NOT RUN, not as a failure. Required gates that did not run still fail the build.
- The scripts are bash and Node; native Windows shells are not supported. On Windows use WSL or Git Bash.

## Contributing

Ideas, bug reports and new stack engines are welcome. Read [CONTRIBUTING](CONTRIBUTING.md).
Questions and ideas belong in [Discussions](https://github.com/mohamad-tn/engineering-rules/discussions).
Bug reports and pull requests go through [Issues](https://github.com/mohamad-tn/engineering-rules/issues).
Please follow the [code of conduct](CODE_OF_CONDUCT.md). Security reports: [SECURITY](SECURITY.md).

## Maintainers

[Mohamad Tonbary](https://github.com/mohamad-tn)

## License

[MIT](LICENSE). If this saves you a bad Friday, a star helps others find it.
