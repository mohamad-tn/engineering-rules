# FAQ

**Is this a linter?** No. Linters check code style. This checks the delivery of change: secrets, size, docs,
configuration, dependencies, flags and whether the stack's own tools (including your linter) passed.
It runs your linter as one gate.

**How is it different from pre-commit hooks?** A hook runs on one machine and can be skipped. Gates run in CI and in the
proof, and the result is visible in the pull request. The installer also adds the secret-scan hook for the local layer.

**Does it replace Dependabot, Renovate, SonarQube or my security scanner?** No. It configures Renovate sensibly and
runs your ecosystem's audit, but it is a small floor, not a full security programme.

**Does any data leave my machine?** No service is involved. The scripts download pinned tool releases from their official
release pages (verified by checksum) and your package manager talks to its registry as usual.

**Can I change the thresholds, or turn a gate off?** Yes. Thresholds live in `.github/engineering-rules.env`.
Switch a gate off on purpose with `STACK_SKIP_GATES` (it then leaves the required list) and write why next to it.

**What does Planned mean?** A rule is described but no script enforces it yet. It is labelled so nobody believes it is checked.

**What happens when a gate cannot run (tool missing, offline)?** It is reported NOT RUN. If the gate is required, the run fails.
`local-proof.sh` also fails unless you pass `--allow-missing`, and then says so in the proof.

**Is it safe on pull requests from forks?** The workflows use `pull_request`, read-only permissions and no persisted credentials.
Remember that stack gates run the project's own commands, as any CI does.

**Which Node, Python, ... versions?** Yours. Pin them in your project (`.nvmrc`, `global.json`, `go.mod`...) and in the workflow setup step.

**Does it work with AI assistants other than Claude?** Yes. The rules are in `AGENTS.md`; the installer adds small bridge files
for Claude, Cursor, Copilot, Gemini and Windsurf. The skill folder works wherever skills folders are read.

**What if my team disagrees with a rule?** Change it: a pull request that edits `AGENTS.md`, adds an ADR with the reason and updates
`docs/rules-compliance.md`. The process for changing rules is itself one of the rules.

**Can I add my own stack or my own gate?** Yes: see [CONTRIBUTING](../CONTRIBUTING.md#add-a-stack). A gate is a command; `STACK_CMD_<GATE>` can also replace one.

**Does it run on macOS and Windows?** On macOS install a current bash (`brew install bash`; the scripts re-run themselves with it and say so if it is missing). On Windows use WSL or Git Bash. Both are covered by simulated tests here and by experimental jobs in the repository CI.

**Why bash?** It is the lowest common denominator on CI runners, laptops, WSL and containers. The heavier logic is in Node.
