---
trigger: always_on
description: Repository engineering rules and pull-request gates
---

Follow `AGENTS.md` at the repository root. Keep tasks small (about 400 changed lines),
run `bash .github/scripts/local-proof.sh` before review, never merge, never commit
secrets, and update docs and `CHANGELOG.md` with the code.
