# Phase gate

Run after the last task of a phase merges and before the next phase starts.
Record the result in `docs/rules-compliance.md` (phase gate log). A failure blocks
the next phase: fix it in a small task, then run the gate again.

## 1. Preconditions

- [ ] Every task of the phase is merged; no pull request of the phase is open.
- [ ] The default branch is green: all required checks pass on its latest commit.
- [ ] `CHANGELOG.md` and `docs/status.md` describe the phase.

## 2. Automated gates on the default branch

- [ ] Secret scan, docs-check, policy gates, flag expiry: pass.
- [ ] Stack gates (build, tests, lint, types, audit): pass.
- [ ] No gate was skipped, and no exception label is hiding a real problem.

## 3. Whole-file compliance walk

Walk `AGENTS.md` section by section. For each section write one line in
`docs/rules-compliance.md`: **Enforced**, **Review**, **Ops** or **Planned**, with the
check or the evidence. A rule that is neither enforced nor reviewed is written down as
**Planned**; it is not silently assumed to hold. Count the Planned rows: the count
should go down over time.

## 4. Smoke test

A short, scripted check against a running environment (not a unit test):

- [ ] the service starts and its health checks report ready;
- [ ] the main user path works end to end (one happy path, one expected failure);
- [ ] a new migration applies to an empty database and to the previous version;
- [ ] no secret or private host appears in the logs of the run.

## 5. Decisions and open questions

- [ ] Every deviation from the rules has an ADR.
- [ ] Open questions are listed with an owner; none was answered by guessing.

## 6. Record

Add a row to the phase gate log: phase, date, result, link to the evidence (CI run,
local proof, smoke-test output). If hosted CI was not used, link the local proof.
