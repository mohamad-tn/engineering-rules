# CLAUDE.md

Read `AGENTS.md` first and follow it. It is the single rules file of this repository.

Short version:

- Work in small tasks. One pull request is about 400 changed lines or fewer.
- Before asking for review run `bash .github/scripts/local-proof.sh` and paste its output into the pull request.
- Never merge, never commit secrets, never hard-code configuration, never skip or weaken a gate.
- If a requirement or a decision is missing, write an open question. Do not guess.
- Update docs and `CHANGELOG.md` in the same pull request as the code.
