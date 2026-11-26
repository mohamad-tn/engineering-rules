# Domain add-on (optional)

> **Optional.** Load this file only if your product is location-based, runs in more
> than one country or region, or is an on-demand marketplace (two sides that are matched
> in real time). A plain CRUD app or a content product skips it entirely: nothing in
> `SKILL.md`, the templates or the gates depends on it.

## How to adopt a module

1. Pick the modules that match your product.
2. Copy each chosen rule into a section 9 ("Domain rules") of your `AGENTS.md`.
3. Add its row to `docs/rules-compliance.md` with an honest status.
4. Add a check only when you can write one; otherwise leave it as **Review** or **Planned**.

All rules below start as **Review** or **Planned**: the package ships no gate for them.

## A. Location data

| Rule | Why | How to check |
|---|---|---|
| Collect the least precise location that does the job; coarse for browsing, precise only for an active trip or delivery | privacy and trust | review of each location use |
| Set and document a retention period for location history; delete or aggregate after it | legal exposure | scheduled job plus runbook (**Planned**) |
| Never log raw coordinates with a user identifier | logs travel widely | log review; a redaction test (**Planned**) |
| Treat a location as untrusted input: validate range, rate and plausibility | spoofing and bad data | unit tests on the validator |
| Ask permission in context, explain why, and work (degraded) when it is refused | store rules and users | UI review |

## B. More than one country or region

| Rule | Why | How to check |
|---|---|---|
| Currency, tax, legal text, phone format, address format and supported languages are configuration per region, not code | adding a region must not need a release | the Universal literals gate (U10) already catches hard-coding |
| Store and compute time in UTC; keep the region's IANA time-zone id; format only at the edge | daylight-saving and travel bugs | run time suites under several zones (D9 in the .NET adapter) |
| Money is an integer in minor units plus a currency code; never a float | rounding errors | unit tests; a lint rule where available |
| Data residency and consent differ by region; record where each class of data lives | compliance | a data map in `docs/` (**Planned**) |
| A region can be switched off without a deploy (kill switch) | incidents and regulation | feature-flag registry with expiry (U11) |

## C. On-demand marketplace (two sides matched in real time)

| Rule | Why | How to check |
|---|---|---|
| Define the state machine of a request (created, offered, accepted, active, completed, cancelled) and allow only listed transitions | races and stuck states | state-machine tests |
| Every action that can be repeated by a retry or a double tap is idempotent (accept, pay, cancel) | duplicate charges and trips | idempotency-key tests |
| Matching and ranking rules are documented and reviewed for fairness; changes get an ADR | trust on both sides | ADR plus review |
| Verify providers before they can take work; re-verify on a schedule | safety | runbook, admin audit (**Planned**) |
| Payments and payouts are reconciled on a schedule; mismatches raise an alert | money bugs hide | reconciliation job plus runbook (**Planned**) |
| Provide a safety path (report, block, emergency contact) with an owner and a response target | harm reduction | UI review, runbook |
| Rate-limit public and anonymous endpoints; list every anonymous endpoint in an allowlist that needs owner review | abuse | allowlist file plus architecture test (**Planned**) |

## D. Real-time and weak connectivity

| Rule | Why | How to check |
|---|---|---|
| Show connection state honestly (online, reconnecting, offline) and never lose a user action silently | field use | UI review, e2e test with the network off |
| Queue offline actions with an idempotency key and replay them in order | no duplicates | replay tests |
| Reconnect with backoff and jitter; resume from the last known state | thundering herd | unit tests on the backoff |
| Degrade gracefully when the real-time channel is down (polling or a stale-data banner) | availability | game-day check in the phase smoke test |

## E. Languages and layout

| Rule | Why | How to check |
|---|---|---|
| Every user-facing string comes from a catalog; a missing key fails CI | silent English fallbacks | a key-parity test per locale (**Planned** until you add it) |
| Right-to-left layouts are tested, with mirrored icons where meaning depends on direction | broken screens | screenshot or e2e test per direction |
| Numbers, dates and currency use locale formatting at the edge only | wrong separators | unit tests |
| Error messages come from a catalog with a stable code, in every supported language | support and translation | catalog parity test (**Planned**) |

## F. Keeping it optional

- Do not reference this file from the default path.
- Do not add a gate that needs these rules to `project-gates.yml`; add a separate workflow.
- A project that drops the module deletes section 9 of its `AGENTS.md` and the matching
  compliance rows, and nothing else changes.
