# Delivery continuity

Delivery must not stop when something outside the repository fails: the CI host,
the forge, a registry, the hosting provider, a quota. This file is the plan: levels
of CI fallback, a register of dependencies, and the CI-minute rules that keep a free
plan enough. Everything here is optional to adopt; start with the register.

## CI levels

One source of truth for CI: the workflow files. Every level runs the same commands.

| Level | When | How | Merging |
|---|---|---|---|
| 0 | normal | hosted runners | after required checks pass |
| 1 | hosted minutes are out, or hosted runners are down | self-hosted runner: set the repository variable `CI_RUNNER` (for example `["self-hosted","linux","x64"]`); jobs already use `runs-on: ${{ fromJSON(vars.CI_RUNNER \|\| '"ubuntu-24.04"') }}`, so no code change | after required checks pass |
| 2 | the forge is up but Actions is down | replay the workflow files with `scripts/ci-local.sh run <repo> --pr <n> --post` (act, host mode); it posts `ci-local/*` statuses | only with every `ci-local/*` job green; rerun hosted CI when it returns |
| 3 | the forge itself is unreachable | `scripts/ci-local.sh run <repo>` offline, or `scripts/local-proof.sh`; review by local diff | nothing is merged; evidence is advisory because steps that call the forge cannot run offline |

At every level: review and gates never relax, assistants never merge, and the level
change is written in `docs/status.md` the same day. Switch back to level 0 as soon as
the cause is gone (for example, when a monthly quota resets); a fallback is not a
new default.

## Dependency register

One row per outside service the workflow depends on. A new dependency adds its row
and its runbook in the pull request that introduces it.

| Dependency | Detect | Fallback | Switch back | Runbook |
|---|---|---|---|---|
| Forge and its CI | status page; `scripts/continuity-check.sh` | levels 1 to 3 above | when green | `docs/runbooks/<ci>.md` |
| Package registry | install step fails; status page | lockfile plus a local cache or mirror | when green | `docs/runbooks/<registry>.md` |
| Hosting provider | health URL (`<health-url>`), provider status page | roll back to the last good release | when green | `docs/runbooks/<host>.md` |
| Secret store | access errors | emergency access procedure | when green | `docs/runbooks/secret-rotation.md` |
| Dependency bot | no pull requests for 2 weeks | run updates by hand | when green | `docs/runbooks/<bot>.md` |

Replace the rows with your real dependencies. Provider fallbacks are for development
and test only; production fallbacks are an owner decision.

## Checks

`scripts/continuity-check.sh` prints one line per check (status pages, hosted jobs
the forge refused to start, `CI_RUNNER` against online runners, disk space) and exits
1 on a failure. Add your own checks as executable files in
`scripts/continuity-checks.d/` (hosting health, a database expiry, a certificate).

## CI-minute rules

These keep a free plan enough and also make CI faster. The `project-gates.yml`
template already follows them.

- One run per change: `concurrency` cancels an older pull-request run; runs on the
  default branch are never cancelled.
- One job for the cheap gates, so one runner start.
- A docs-only change skips the heavy steps but the **check still reports**, so the
  required check does not hang. Skip the steps, not the job. The default branch always
  runs everything: no path filter on `push`.
- Set `timeout-minutes` on every job.
- Cache the package manager and build caches.
- Do not run the same work twice (a pull request and a push to its branch).
- Reruns after a fix use the same commit; do not trigger a second workflow for the
  same check.
- Workflows avoid host-specific features that act's host mode lacks (service
  containers, background processes that outlive a step), so every level runs the same
  steps.

## Review of this file

Review the register every quarter and after every incident. If an outage taught you a
new dependency, add its row first, then write the runbook.
