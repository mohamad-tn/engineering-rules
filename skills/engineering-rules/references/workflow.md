# Delivery workflow

How work moves from an idea to a merged change. The rules themselves are in the
project's `AGENTS.md` (starter: [`../templates/AGENTS.md`](../templates/AGENTS.md));
the full rule-to-check map is [`rules-index.md`](rules-index.md). This file is only
the loop.

## The loop

```text
roadmap -> phase -> task (about one pull request) -> task gates -> review -> merge
                        \_ after the last task of a phase: phase gate -> next phase
```

1. **Roadmap.** A short list of phases. Each phase has a goal you can verify.
2. **Task.** Numbered, small, one pull request, about 400 changed lines or fewer.
   Larger work is split. A task that cannot be split carries the `pr-size-reason`
   label and a written reason.
3. **Task gates.** Before review the pull request passes every gate in the
   `AGENTS.md` table: secret scan, docs-check, dependency-bot config, policy gates,
   flag expiry, PR size, and the stack gates. Proof is either a green CI run or a
   pasted local proof ([`local-proof.md`](local-proof.md)).
4. **Review.** A human reviews against the Definition of Done in the pull request
   template. Code owners review sensitive paths.
5. **Merge.** A human merges. Assistants never merge, on any CI level.
6. **Phase gate.** When the last task of a phase merges, run the phase gate
   ([`phase-gate.md`](phase-gate.md)). A failure blocks the next phase.

## Rules of the loop

- **Open questions, not guesses.** When a requirement or a decision is missing, write
  it down as an open question and ask. Never invent a requirement to keep moving.
- **Decisions are recorded.** A new dependency, a deviation from the rules file, or a
  new cross-cutting pattern gets an ADR ([`../templates/docs/adr/0000-template.md`](../templates/docs/adr/0000-template.md)).
- **Docs and code move together.** The docs map says which docs a code path needs;
  docs-check enforces it. The changelog is updated unless the title type is exempt.
- **Planned is not enforced.** Anything not yet checked by a gate is labelled
  **Planned** everywhere it appears. Do not describe it as a rule that is enforced.
- **Gates never relax to save time.** A faster path is an owner decision recorded as
  an ADR, not something an assistant or a developer chooses in the moment.
- **Status stays visible.** Keep `docs/status.md` current. When delivery runs below
  level 0 ([`continuity.md`](continuity.md)), say so there the same day.

## Roles

| Role | Does | Never does |
|---|---|---|
| Developer or assistant | writes the change, runs the gates, fills the pull request template | merges, edits a synced rules file in place, allowlists a secret |
| Reviewer | checks the Definition of Done, accepts or rejects exception reasons | approves a failed or missing gate |
| Owner | decides exceptions to the rules, approves ADRs, sets CODEOWNERS | skips the record of a decision |

## Branch protection (a forge setting, not a file)

Set these on the default branch; the templates assume them:

- require a pull request, and at least one approving review;
- require review from code owners;
- require the `project-gates / gates` check (and your stack checks) to pass;
- block force-pushes and deletion;
- require the branch to be up to date before merging, if your team merges often.

## Single repository or several

One repository: copy the templates into it. Several repositories: one of them
(`infra`) owns the shared gates, the rules file and the tool pins; the others call
the shared gates through composite actions pinned to a reviewed commit and carry a
byte-identical copy of the rules file. See the README, sections "Adopt in a single
repository" and "Adopt in several repositories".
