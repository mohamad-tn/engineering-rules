# AGENTS.md: engineering rules

This file is the single rules file for the repository. People and coding
assistants (any tool) follow it the same way. Words: **MUST** is binding,
**SHOULD** needs a written reason to skip, **MAY** is optional.

> Starter from `engineering-rules-skill`. Fill in the `<placeholders>` and delete
> what you do not use. Detail lives in the skill's `references/` folder (installed with the
> skill, not in this repository); this file stays short on purpose. Items marked **Planned** are not enforced yet.

## 1. Scope and ownership

- This file is the only rules file. Do not create a second, competing one.
- In a multi-repository project one repository (`infra`) owns the canonical copy;
  the others carry a byte-identical copy and MUST NOT edit it in place.
- Rules about location, multi-country or on-demand marketplaces are **not** part of
  this file. Add them only if your product needs them (`references/domain-optional.md`).

## 2. Delivery

1. Work in small phases made of numbered tasks. One task is about one pull
   request and under about 400 changed lines.
2. Every task passes the gates in section 5 before review.
3. After each phase, run the phase gate (`references/phase-gate.md`). A failure
   blocks the next phase.
4. Assistants MUST NOT merge. A human reviews and merges.
5. If a rule is unclear or a decision is missing, write an open question. Do not
   guess and do not invent a requirement.

## 3. Definition of done

A change is done when:

- [ ] behavior is covered by tests that fail without the change;
- [ ] the gates in section 5 pass (CI, or the local proof in section 6);
- [ ] docs changed with the code and `CHANGELOG.md` has an entry (or the title type is `chore`/`ci`/`test`);
- [ ] no secret, token, private host or personal data was added;
- [ ] a new dependency, a deviation from this file, or a new pattern has a decision record (ADR);
- [ ] the pull request is within the size limit, or carries the reason label and a written reason.

## 4. Core rules

- **Secrets.** MUST NOT be committed. A finding is rotated, never allowlisted.
- **Dependencies.** Versions are pinned and lockfiles committed. Prerelease
  versions need an ADR. Updates come through the dependency bot and are reviewed.
- **Configuration is data.** Product code MUST NOT hard-code a currency, region,
  time zone, dial prefix, host or named place. Read them from configuration.
- **Failure handling.** Every network call has a timeout. Retry only idempotent
  operations. Logs MUST NOT contain secrets or personal data.
- **Feature flags.** Each flag has an owner, a purpose and an expiry date. An
  expired flag fails the check until it is removed or extended with a reason.
- **Documentation travels with code.** The docs map (`docs/docs-map.yml`) says which docs
  a code path needs.
- **Decisions.** Record them as ADRs. An unresolved decision is an open question.
- **CI and tools.** GitHub Actions are pinned to commit SHAs and downloaded tools to checksum-verified
  versions. CI runs once per change, every job has a timeout, and a superseded run is cancelled.
- **Runbooks.** Every alert has a runbook. A runbook marked Planned is a promise, not a procedure.
- **Duplication.** Copy-paste above the threshold is extracted (stack adapters set the tool and number).

## 5. Gates

| Gate | What it checks | Run locally | Status |
|---|---|---|---|
| Secret scan | full git history, redacted output, no ignore file | `.github/scripts/gitleaks-scan.sh` | Enforced |
| docs-check | required docs, docs map, changelog, markdown lint, internal links | `.github/scripts/docs-check.sh` | Enforced |
| Dependency-bot config | `renovate.json` valid and extends the shared preset | `.github/scripts/renovate-config-check.sh` | Enforced |
| Policy gates | prerelease dependencies, environment literals | `.github/scripts/policy-gates.mjs` | Enforced |
| Flag expiry | every flag has owner, purpose, future expiry | `.github/scripts/feature-flag-expiry.mjs` | Enforced |
| PR size | counted lines under the limit (lockfiles, snapshots excluded) | `.github/scripts/pr-size-check.sh` | Enforced |
| Stack gates | install, tests, build; lint, types, format, audit in strict | `.github/scripts/stack-gates.sh` | Enforced |
| Phase gate | whole-file compliance walk and smoke test | `references/phase-gate.md` | Manual |

Anything not in this table is **Planned**, not enforced.

## 6. Proof without paid CI

Hosted CI is optional. The same scripts run on a developer machine. When CI cannot
run, run `.github/scripts/local-proof.sh`, paste its output into the pull request, and the
reviewer treats it as the proof. A gate that did not run is not proof.
Fallback levels: `references/continuity.md`.

## 7. Governance

- Changing this file needs a pull request, an ADR for the reason, and an update
  to `docs/rules-compliance.md` (which rule is enforced by which check).
- Exceptions use the labels `no-docs-needed` and `pr-size-reason`, each with a
  written reason in the pull request. The reviewer accepts or rejects the reason.
- Owners of sensitive paths are listed in `CODEOWNERS`.

## 8. Optional adapters

Stack gates run with `.github/scripts/stack-gates.sh` (details in `references/stacks/`).
Domain: `references/domain-optional.md`. Load them only when your project uses them.
