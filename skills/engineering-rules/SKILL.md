---
name: engineering-rules
description: Engineering rules, pull-request gates and a small-phase delivery workflow for any software project and stack, tool-agnostic (Claude Code, Cursor, Codex, Copilot, Gemini, or a human reviewer). Use it when setting up or auditing a repository's engineering process - writing AGENTS.md, a pull-request template, CODEOWNERS, secret scanning (gitleaks), docs-check, dependency-bot (Renovate) config, PR-size limits, policy gates, phase gates - or when running build, test, lint and audit gates for Node, Next.js, React, React Native, Vue, Angular, .NET, Laravel/PHP, Flutter, Python/Django, Java/Spring, Go, Rust, Ruby/Rails, C/C++, Swift, Terraform or Docker projects, including monorepos. Also use it when the user wants these checks to run locally without paid CI and be proven in the pull request. A location/marketplace domain add-on is optional and loaded only on request.
license: MIT
compatibility: Needs git and bash; Node 20+ for the gate scripts; jq for the PR-size labels. The GitHub Actions templates are optional; every gate also runs locally.
metadata:
  version: "1.1.0"
  language: en
  scope: universal core with optional stack and domain adapters
---

# Engineering rules skill

A small universal core: rules, pull-request gates and a delivery loop that fit any software
project, in any language or framework. Detail is in `references/`; ready-to-copy files are in
`templates/` and `scripts/`. Load only what the task needs.

## When to use

- Start or audit a repository's engineering process (new or existing).
- Write or review `AGENTS.md`, the pull-request template, `CODEOWNERS`, CI gates.
- Add secret scanning, docs-check, PR-size limits, a dependency-bot config.
- Run stack gates (install, tests, build, lint, audit) on any repository, monorepos included.
- Plan work in phases and tasks, or run a phase gate.
- Prove the gates without hosted or paid CI.

Do not use it to invent product requirements, and do not load the domain file unless the
product needs it.

## The core in six lines

1. Work in small phases of numbered tasks; one task is about one pull request, about 400 lines or fewer.
2. Every task passes the gates before review: secret scan, docs-check, dependency-bot config, policy gates, flag expiry, PR size, plus stack gates.
3. Proof is a green CI run **or** the output of `local-proof.sh` pasted into the pull request (`--json` for machine-readable results). A gate that did not run is not proof.
4. Docs move with code (docs map, changelog); decisions are ADRs; a missing decision is an open question, never a guess.
5. Humans merge. Assistants never merge, on any CI level.
6. Anything not yet enforced is labelled **Planned**. Never present it as enforced.

The complete, binding rule set is `templates/AGENTS.md` (about 1.4k tokens). Read it in full before you
advise, review or change anything, and never reconstruct the rules from memory.

## What an agent does

| Request | Do this |
|---|---|
| "Set up the process in this repo" | Run `scripts/install.sh --target <repo>`; fill the placeholders; run `doctor.sh`, then `local-proof.sh`. |
| "Run the checks for this project" | Run `stack-gates.sh`: it detects the stack (Node, Next.js, React, .NET, Laravel, Flutter, Python, Java, Go, Rust, Ruby, C/C++, Swift, Terraform, Docker) and runs its gates. |
| "Add a rule" | Check `references/rules-index.md` first. Add it to `AGENTS.md`, add a row to `docs/rules-compliance.md` with an honest status, and write an ADR. |
| "Review this pull request" | Check the Definition of Done in the template, the gate rows, and that exception labels have a written reason. |
| "CI is down or out of minutes" | Follow `references/continuity.md`; run `local-proof.sh`; do not relax a gate. |
| "A gate failed" | Read `references/fixing-failures.md`; run `local-proof.sh --json`, fix each `FAIL` at its cause, never weaken the gate. |
| "Update the installed rules" | Run `scripts/install.sh --target <repo> --update`: scripts and workflows are refreshed, your edits are kept (new versions land as `.new`). |
| "End of phase" | Run `references/phase-gate.md` and log the result. |

## Hard rules for the agent

- Never merge, never allowlist a secret, never edit a synced rules file in place.
- Never skip or weaken a gate to finish faster; propose an ADR instead.
- Never add real names, hosts, tokens, account ids or private task ids to files. Use
  placeholders: `<org>`, `<owner>`, `<project>`, `@<owner>`, `api.example.com`.
- Keep Planned items marked Planned. Keep the default path free of domain rules.

## Where things are

| Need | File |
|---|---|
| The delivery loop, roles, branch protection | `references/workflow.md` |
| Every rule, scope, check and status | `references/rules-index.md` |
| Run the gates locally and paste proof | `references/local-proof.md` |
| What to do when a gate fails | `references/fixing-failures.md` |
| Phase gate checklist | `references/phase-gate.md` |
| CI fallback levels, dependency register, CI-minute rules | `references/continuity.md` |
| Stack gates for Node, React, Vue, Angular, Next.js, React Native, .NET, Laravel/PHP, Flutter, Python, Java, Go, Rust, Ruby, C/C++, Swift, Terraform, Docker | `references/stacks/README.md` and `references/stacks/<stack>.md` |
| Location, multi-country, marketplace rules (optional) | `references/domain-optional.md` |
| Starter `AGENTS.md`, PR template, CODEOWNERS, hooks, scanner and bot config, CI workflows, docs starters, assistant bridge files | `templates/` |
| Gate scripts, installer, doctor, self-test | `scripts/` |

## Adoption in one paragraph

From the target repository run `bash <skill>/scripts/install.sh --target . --profile standard`;
fill the placeholders (owners, thresholds, docs map, CI provider, tool pins); run
`bash .github/scripts/doctor.sh`, then `bash .github/scripts/local-proof.sh`; open the first
pull request with the proof pasted in.
