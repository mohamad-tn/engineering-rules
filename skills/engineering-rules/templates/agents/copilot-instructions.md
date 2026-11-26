# Copilot instructions

Follow `AGENTS.md` at the repository root. It is the single rules file.

- Keep changes small (about 400 lines per pull request) and update docs and `CHANGELOG.md` with the code.
- Do not commit secrets or hard-code configuration (currency, region, host, time zone).
- Run `bash .github/scripts/local-proof.sh` before asking for review and paste its output into the pull request.
- If something is unclear, ask or write an open question. Do not invent requirements.
