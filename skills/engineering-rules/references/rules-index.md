# Rules index

Every rule, its scope, how it is checked, and its honest status. This is the map to
copy into your `docs/rules-compliance.md`. The **Scope** column decides where a rule
lives:

- **Universal**: any software project. These are the default path.
- **Stack**: only if you use that stack. Detail is in [`stacks/`](stacks/README.md).
- **Domain**: only for location-based, multi-country or on-demand marketplace
  products. Detail is in [`domain-optional.md`](domain-optional.md). Never part of the default path.

**Status.** *Enforced*: a script fails the pull request. *Implemented*: the tool
exists but is not wired as a required check until you do it. *Review*: a reviewer
checks it. *Ops*: a runbook or a schedule. *Planned*: not enforced yet; never present
it as a rule that holds.

## Universal

| # | Rule | Scope | Checked by | Status |
|---|---|---|---|---|
| U1 | One rules file; copies elsewhere are byte-identical and never edited in place | Universal | `scripts/sync-rules-file.sh` (multi-repo), review | Implemented |
| U2 | Small phases and tasks; one pull request is about 400 lines or fewer | Universal | `pr-size-check.sh` (warn 400, fail 800 with reason label) | Enforced |
| U3 | Task gates pass before review; proof is CI or a pasted local proof | Universal | `project-gates.yml`, `local-proof.sh` | Enforced |
| U4 | Phase gate after every phase; a failure blocks the next phase | Universal | [`phase-gate.md`](phase-gate.md), compliance log | Review |
| U5 | Assistants never merge; humans review and merge | Universal | branch protection, CODEOWNERS | Review |
| U6 | No secrets in git; full-history scan; no ignore file; rotate, never allowlist | Universal | `gitleaks-scan.sh`, `gitleaks.toml`, pre-commit hook | Enforced |
| U7 | Docs travel with code: required docs, docs map, changelog, markdown lint, internal links | Universal | `docs-check.sh` | Enforced |
| U8 | Dependencies pinned, lockfiles committed, updates through the bot | Universal | `renovate-config-check.sh`; frozen install in stack gates | Enforced |
| U9 | No prerelease dependency without an ADR and an allowlist entry | Universal | `policy-gates.mjs` | Enforced |
| U10 | Configuration is data: no hard-coded currency, region, time zone, dial prefix or named place in product code | Universal | `policy-gates.mjs` + `policy/country-literals.json` | Enforced |
| U11 | Feature flags have owner, purpose and expiry; expired flags fail | Universal | `feature-flag-expiry.mjs` | Enforced |
| U12 | A flag still read in code after it is retired fails | Universal | needs a code scan per stack | Planned |
| U13 | Decisions are ADRs; an unresolved decision is an open question, not a guess | Universal | review | Review |
| U14 | Exceptions only by label plus written reason (`no-docs-needed`, `pr-size-reason`) | Universal | docs-check, PR size, review | Enforced |
| U15 | Failure handling: timeouts on network calls, retries only for idempotent operations, no secrets or personal data in logs | Universal | review; stack lint rules where available | Review |
| U16 | Actions pinned to commit SHAs; downloaded tools pinned and checksum-verified | Universal | dependency bot digest pinning, `install-release-tool.sh` | Enforced |
| U17 | Cross-language artifacts that must stay byte-identical have a SHA-256 lock | Universal | `assert-sha256-lock.mjs` in a project check | Implemented |
| U18 | CI-minute hygiene: one run per change, cancel superseded runs, skip heavy steps on docs-only changes, timeouts, caches | Universal | `project-gates.yml` pattern | Review |
| U19 | Delivery continuity: every outside dependency has detect, fallback, switch-back and a runbook | Universal | [`continuity.md`](continuity.md), `continuity-check.sh` | Ops |
| U20 | Runbooks per alert; `Planned` status is honest until verified | Universal | review | Review |
| U21 | Rules file changes need an ADR and an update of the compliance table | Universal | docs-map rule on `AGENTS.md` | Enforced |

## Stack gates (all stacks)

Run by `scripts/stack-gates.sh`, one engine per stack. See [`stacks/README.md`](stacks/README.md).

| # | Rule | Scope | Checked by | Status |
|---|---|---|---|---|
| S1 | A clean, locked install works; lockfiles are committed | Stack | `deps` gate (all engines) | Enforced |
| S2 | Tests pass | Stack | `test` gate | Enforced |
| S3 | The production build succeeds | Stack | `build` gate | Enforced |
| S4 | A gate that did not run is never a pass: required gates fail on SKIP and NOT RUN | Stack | `STACK_REQUIRE` policy in `stack-gates.sh` | Enforced |
| S5 | Formatting, lint and type checks pass | Stack | `format`, `lint`, `types` gates | Enforced in profile `strict`; otherwise listed in `STACK_REQUIRE` |
| S6 | No known-vulnerable runtime dependency | Stack | `audit` gate (npm, pnpm, yarn, composer, dotnet; cargo-audit, pip-audit, govulncheck, bundler-audit and OWASP when installed) | Enforced in `strict`; NOT RUN when the tool is missing |
| S7 | Client bundle contains no private backend host | Stack (Next.js, web) | `bundle-scan` gate | Enforced when `API_BASE_URL` is set |
| S8 | No keystore, credentials file or private key tracked; no literal signing password; no cleartext URL | Stack (React Native, Flutter) | `secrets-files` gate | Enforced |
| S9 | Python requirements are pinned; Django model changes have migrations | Stack (Python) | `pinned`, `migrations` gates | Enforced |
| S10 | `go.mod` is tidy; `Cargo.lock` is committed for binaries | Stack (Go, Rust) | `mod-tidy`, `deps` gates | Enforced |
| S11 | Layer dependencies and banned APIs (architecture tests) | Stack | tests you write in your language | Planned |
| S12 | Migration SQL linted and applied to an empty database in CI | Stack | depends on your database | Planned |
| S13 | Container images build from a clean context | Stack | `docker build` job you add | Planned |
| S14 | Time-dependent tests run under several time zones | Stack | a CI matrix you add (`TZ=`) | Planned |
| S15 | Installable test builds with a checksum, built on demand (mobile) | Stack | a `workflow_dispatch` job you add | Planned |

## Domain (optional)

Rules for location, multi-country and on-demand marketplace products are listed in
[`domain-optional.md`](domain-optional.md) with their own status. They are **not**
counted in the Universal rows above, and no gate in the default path depends on them.
