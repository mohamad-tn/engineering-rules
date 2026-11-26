# Rules compliance

Which rule is enforced by which check. Update this table in the same pull request
that changes `AGENTS.md` or a gate. Status values: **Enforced** (a check fails the
pull request), **Review** (a reviewer checks it), **Ops** (a runbook or a schedule),
**Planned** (not enforced yet; do not rely on it).

| Section | Rule | Enforced by | Status |
|---|---|---|---|
| 4 | Secrets are not committed | secret scan | Enforced |
| 4 | Dependencies pinned, no prerelease without ADR | policy gates, dependency bot | Enforced |
| 4 | Configuration is data | policy gates (literals) | Enforced |
| 4 | Feature flags expire | flag-expiry gate | Enforced |
| 4 | Docs travel with code | docs-check | Enforced |
| 3 | Size limit | PR size gate | Enforced |
| 4 | Failure handling | code review | Review |
| 4 | Duplication threshold | stack gate | Planned |

## Phase gate log

| Phase | Date | Result | Evidence |
|---|---|---|---|
| `<phase>` | `<YYYY-MM-DD>` | pass / fail | `<link>` |
