# Contributing

Thank you for helping. This project is small on purpose: a short universal core, optional
stack engines, and an optional domain module. Decide which one your change belongs to first.

| Tier | Lives in | Rule of thumb |
|---|---|---|
| **Universal rule or gate** | `skills/engineering-rules/templates/AGENTS.md`, `references/rules-index.md`, `scripts/` | true for any software project, no stack or product assumption |
| **Stack engine** | `skills/engineering-rules/scripts/stacks/<name>.sh`, `references/stacks/<name>.md` | true only when the project uses that stack |
| **Domain add-on** | `skills/engineering-rules/references/domain-optional.md` | true only for a kind of product (location, multi-country, marketplace) |

## Talk to us

Questions and ideas: open a [Discussion](https://github.com/mohamad-tn/engineering-rules/discussions).
Bug reports and pull requests: open an [Issue](https://github.com/mohamad-tn/engineering-rules/issues) or a pull request.
Security reports: follow [SECURITY](SECURITY.md). Please do not put a vulnerability in a public issue.

## Set up

You need `bash`, `git`, `node` (20 or newer) and `shellcheck`. Optional, so more tests run for real:
`go`, `cargo`, `python3`, `bundler`, `dotnet`, `php` and `composer`, `npm`, `jq`.

```bash
bash tests/run-all.sh            # everything; suites skip what is not installed
bash tests/run-all.sh stacks     # one suite
bash examples/shop-api/run-demo.sh
```

## Propose a universal rule

A universal rule must pass all of these:

1. A plain CRUD app and a content site could follow it without changing anything else.
2. It says how it is checked: a script (**Enforced**), a tool shipped but not required (**Implemented**), a reviewer (**Review**),
   a runbook (**Ops**), or nothing yet (**Planned**). Be honest. Never write Enforced without a script that fails.
3. It is short: one sentence for the rule, one for why.
4. It does not duplicate an existing rule. Link instead.

Add the rule to `templates/AGENTS.md` (only if it belongs in the short starter), a row to `references/rules-index.md`,
and, if enforced, the script and a case in `scripts/selftest.sh`.

## Add a stack

1. **Engine:** `skills/engineering-rules/scripts/stacks/<name>.sh` defining `run_<name>`. Use the helpers in
   `stacks/lib.sh`: `gate`, `gate_net` (network failure means NOT RUN), `gate_sh`, `skip`, `na`, `warn`, `notrun`, `fail`, `pass`.
   Use the standard gate names (`deps`, `format`, `lint`, `types`, `test`, `build`, `audit`) and add extras only when they are real checks.
   Never let a gate pass when nothing ran.
2. **Detection:** add the marker file to `detect()` in `scripts/stack-gates.sh`.
3. **Workflow:** `templates/stacks/<name>/ci.yml` (pin actions to commit SHAs; run `stack-gates.sh --engine <name>`);
   optional tool configs in `templates/stacks/<name>/configs/`.
4. **Reference:** `references/stacks/<name>.md` and a row in `references/stacks/README.md`.
5. **Tests:** a good and a bad fixture in `tests/fixtures/<name>/` and cases in `tests/test-stacks.sh`. Prefer the real toolchain;
   if it cannot run everywhere, add a stub case too and say so in `docs/testing.md`.
6. Update the table in `README.md`.

## Propose a domain add-on

Add a module to `references/domain-optional.md`. Every rule starts as **Review** or **Planned**. A gate belongs in a separate
workflow, never in the default `project-gates.yml`. If your change needs `SKILL.md`, a template or a core script to mention the
domain, it is a universal change instead.

## Rules for every contribution

- No real project, company or personal names, private hosts, secrets, internal task ids, billing notes or account ids.
  Use `<org>`, `<owner>`, `<project>`, `api.example.com`. Do not add `.env`, key or keystore files, even fake ones; the static suite fails on them.
- Pin what you add: tool versions with checksums, GitHub Actions by commit SHA.
- Keep the core small. Detail goes in one reference file, with links from elsewhere.
- Planned stays Planned until a script enforces it.
- Translations: the Arabic edition (`skills/engineering-rules-ar/`, `README.ar.md`, `docs/ar/`) mirrors the English one. Change both in the same pull request, or open an issue asking for the translation.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`). Update `CHANGELOG.md` for user-visible changes.

## Before you open a pull request

```bash
bash tests/run-all.sh
```

The pull request template has the checklist. Pull requests are reviewed by a human, and, as this project preaches, small ones are reviewed faster.
