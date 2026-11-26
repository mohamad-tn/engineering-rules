# Local proof: running the gates without paid CI

The gates are plain scripts. CI only calls them. So everything CI checks can be
checked on a developer machine, and the result pasted into the pull request.
Use this when hosted CI is off (no minutes, an outage, no plan), or simply before
you push.

## One command

From the repository root, with the work committed:

```bash
bash .github/scripts/local-proof.sh --title "feat: my change"
```

It runs secret scan, docs-check, policy gates, flag expiry, PR size, the **stack gates**
of every stack it detects, and (if the file exists) the dependency-bot check, then prints a
Markdown block with the commit, the date and a PASS/FAIL row per gate. Options:

| Option | Meaning |
|---|---|
| `--base <sha>` | base commit; default is the merge-base with `origin/main` |
| `--title "<text>"` | the pull-request title the docs-check changelog rule reads; default is the last commit subject |
| `--label <name>` | a label the pull request carries (repeatable), for example `no-docs-needed` |
| `--fast` | skip build and audit in the stack gates (a quick loop while coding; run without it before you ask for review) |
| `--no-stack` | skip the stack gates and say so in the proof |
| `--allow-missing` | do not fail when a tool is missing; the gate is still shown as NOT RUN |
| `--out <file>` | also write the block to a file |
| `--json` | JSON on stdout; Markdown goes to stderr or `--out` |

Without `--allow-missing`, exit status is non-zero if a gate failed or did not run. `--no-stack` also marks the stack gates as not run. With `--allow-missing`, a missing gate may be allowed to produce exit 0 for scripting, but the proof remains incomplete: JSON reports `ok: false` for `NOT_RUN` or `SKIPPED`. Do not present an incomplete result as a passing proof.

`--fast` may exit 0 for the development loop while its stack row is `SKIPPED` (build/audit). JSON separates `execution_ok` from `proof_complete`; `ok` is an alias of `proof_complete`, not command success. `stack_mode` is `full`, `fast`, or `skipped`. A fast run of a detected stack is never full proof; rerun without `--fast` before review. These fields summarize the configured top-level gates, not every possible security or optional stack check.

## Run one gate

| Gate | Command |
|---|---|
| Secret scan | `bash .github/scripts/gitleaks-scan.sh .gitleaks.toml` |
| docs-check | `bash .github/scripts/docs-check.sh .` (set `BASE_SHA`, `HEAD_SHA`, `PR_TITLE`, `PR_LABELS_JSON` to apply the pull-request rules) |
| Dependency-bot config | `bash .github/scripts/renovate-config-check.sh .` |
| Policy gates | `node .github/scripts/policy-gates.mjs .` |
| Flag expiry | `node .github/scripts/feature-flag-expiry.mjs .` |
| PR size | `BASE_SHA=<sha> HEAD_SHA=<sha> bash .github/scripts/pr-size-check.sh` (with no variables it uses `origin/main...HEAD`) |
| Stack gates | `bash .github/scripts/stack-gates.sh` (`--fast` skips build and audit; `--list` shows what it detects) |

Tool versions and checksums are pinned in `.github/tool-pins.env`. A tool already on
your `PATH` is used as is; otherwise the pinned release is downloaded and its
SHA-256 verified (Linux x64). On macOS or Windows, install `gitleaks` and `lychee`
with your package manager.

## Replaying the real workflow files

When you need the exact workflow files to run (for example, a CI job that is not a
plain script), `scripts/ci-local.sh` replays them on your machine with `act` in
host mode and can post `ci-local/*` commit statuses. That is level 2 or 3 of
[`continuity.md`](continuity.md).

## What the reviewer does with a local proof

1. Checks the commit in the proof equals the pull request head.
2. Checks every row is PASS and none is NOT RUN.
3. For anything risky, runs the one-liner again on their own machine.

When hosted CI returns, rerun it on the same pull request. The local proof is a
substitute, not a replacement.
