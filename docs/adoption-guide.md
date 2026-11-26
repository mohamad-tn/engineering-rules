# Adoption guide

## Pick a profile

| Profile | For | Size limit (warn / fail) | Required stack gates |
|---|---|---|---|
| `lite` | solo work, prototypes | 600 / 1200 | `deps`, `test` |
| `standard` | most products (default) | 400 / 800 | `deps`, `test`, `build` |
| `strict` | teams, regulated products, public libraries | 300 / 600 | standard, plus `format`, `lint`, `types`, `audit` |

The profile is a small file, `.github/engineering-rules.env`. Edit any value later.

## A new repository

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project --profile standard
```

Fill the placeholders, run `doctor.sh`, commit, run `local-proof.sh`. Done.

## An existing repository (the realistic path)

1. Install with `--profile lite`. Nothing is overwritten.
2. Run `bash .github/scripts/local-proof.sh`. Expect failures; they are your backlog.
3. Fix the ones that matter first: committed secrets (rotate them), then missing lockfiles, then failing tests.
3b. Messy old markdown does not block you: in profiles `lite` and `standard` only the files a pull request changes are linted and link-checked (`DOCS_LINT_SCOPE=all` lints everything).
3c. Old secrets in history: rotate them, record an ADR, then set `SECRET_SCAN_FROM=<adoption commit>` in `.github/engineering-rules.env`. The scan then covers newer commits only and says so loudly.
4. For a gate you cannot satisfy yet, switch it off **on purpose**: `STACK_SKIP_GATES=audit` in
   `.github/engineering-rules.env`, with a dated comment and a task to remove it. A gate you switched off
   leaves the required list; one that silently does nothing does not.
5. Move to `standard` when `lite` is green, then `strict` when you want it.

Old history that contains a secret: rotate the secret. Rewriting shared history is a separate decision;
the secret scan can be pointed at new commits only by your team's process, never by an ignore file.

## A monorepo

Every project is detected (`web/` Next.js, `api/` Go, `mobile/` Expo...) and gets its own run. Use
`STACK_EXCLUDE="examples/ third_party/"` to ignore folders, or `.github/engineering-rules.stacks` to list projects.
Each stack has its own workflow file; each runs only its engine (`--engine`).

## Several repositories (backend, web, mobile, infra)

One repository (`infra`) owns the shared gates, the rules file and the tool pins. The others use
`--layout member`, which installs `project-gates.multi-repo.yml`: it calls composite actions from `infra`, pinned to a
reviewed commit, so a repository cannot weaken a gate. Keep one `AGENTS.md`; open update pull requests with
`scripts/sync-rules-file.sh`. The `infra` layout is described in
[`templates/shared-actions/`](../skills/engineering-rules/templates/shared-actions).

## Upgrading the installed rules

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project --update
```

`--update` refreshes only what the skill owns (`.github/scripts/**` and the gate workflows). It remembers what it installed in
`.github/engineering-rules.manifest`: a file you did not touch is updated; a file you edited is kept and the new version is written
next to it as `.new`, so you can compare and merge. `AGENTS.md`, docs, CODEOWNERS and configs are never touched. If `.github/tool-pins.env`
differs from the new version's pins, you are told.

## Branch protection (a setting, not a file)

On the default branch: require a pull request, one approval, code-owner review, and the checks
`project-gates / gates` and your `stack-*` checks; block force-push. `doctor.sh` reads these settings when `gh` is available.

## Day-two habits

- Update `docs/status.md` when a phase starts or ends.
- Keep `docs/rules-compliance.md` honest; count the Planned rows and let the number fall.
- Review `.github/tool-pins.env` and the Renovate preset on a schedule.
