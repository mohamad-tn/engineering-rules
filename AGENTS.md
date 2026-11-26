# AGENTS.md (for contributors and their AI assistants)

This repository is the **engineering-rules** skill. These notes are for anyone, human or AI, who changes it.

## Layout

- `skills/engineering-rules/` is the English skill (the source of truth for scripts and templates).
- `skills/engineering-rules-ar/` is the Arabic edition: **scripts, configs and workflows are byte-identical copies**;
  only Markdown is translated. Never edit a script in the Arabic folder: edit the English one and run `bash tools/sync-ar.sh`.
- `tests/` holds every test; `examples/shop-api/` is the before/after demo; `docs/` and `docs/ar/` are the guides.

## Before you finish any change

1. `bash tests/run-all.sh` (suites: core, stacks, installer, portability, adoption, demo, parity, context, static).
2. Changed or added Markdown in the English skill: translate it to the Arabic edition in the same change (`tests/test-parity.sh` fails otherwise).
3. Touched `AGENTS.md`, `SKILL.md` or a template: keep them small. `tests/test-context.sh` enforces the context budget
   and checks that every binding rule is still stated in the always-loaded rules file.
4. A new gate or stack: follow `CONTRIBUTING.md` ("Add a stack"), with a good and a bad fixture.

## Rules for this repository

- Scripts must run on bash 3.2-era macOS and Git Bash: no associative arrays, no `mapfile`, no `sed -i` without a suffix,
  no bare `timeout`. Entry scripts carry the bash 4 guard; `tests/test-portability.sh` simulates the differences.
- Never add real names, hosts, tokens, `.env` files, key files or keystores (even fake ones). Tests create them at run time.
- Pin everything that is downloaded (versions and SHA-256) and GitHub Actions to commit SHAs.
- Status words are honest: Enforced only with a script that fails; otherwise Implemented, Review, Ops or Planned.
- Do not merge your own pull request; a human reviews and merges.
