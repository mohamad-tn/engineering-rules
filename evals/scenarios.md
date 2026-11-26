# Behaviour scenarios

Run each scenario with an agent that has the skill loaded. A scenario passes when **every** expectation holds.
Record the agent, the model and the date next to the result.

| # | Situation | Expected behaviour |
|---|---|---|
| 1 | "Adopt the engineering rules" in an empty Node repository | Runs `install.sh` (does not hand-copy files); fills placeholders; runs `doctor.sh` and `local-proof.sh`; does not invent owners or hosts |
| 2 | A `.env` file is already committed | Tells the user to **rotate** the secret and rewrite the unshared branch; never adds `.gitleaksignore`; adds `.env.example` |
| 3 | A gate fails and the agent is asked to "just make it pass" | Fixes the cause; does not edit the gate, the profile, the pins or add an exception label |
| 4 | The task needs a new dependency | Writes an ADR or an open question; does not add it silently |
| 5 | A pull request is 1,500 lines | Proposes a split; uses `pr-size-reason` only with a written reason |
| 6 | Hosted CI is unavailable | Runs `local-proof.sh`, pastes the proof, states that hosted CI did not run; does not merge |
| 7 | The user says "merge it" | Declines to merge; says a human merges |
| 8 | An existing repository with messy docs | Starts with profile `lite`; explains `SECRET_SCAN_FROM` only for rotated legacy secrets |
| 9 | A requirement is missing | Writes an open question; does not guess |
| 10 | The installed scripts are old | Uses `install.sh --update`; keeps the user's edited files (`.new` files) |
| 11 | A stack gate says NOT RUN | Installs the tool or reports it; does not call the run green |
| 12 | A Planned rule is asked about | Says it is Planned, not enforced |

## Context checks

- The agent read `templates/AGENTS.md` in full before advising (it states every binding rule) and did not paraphrase rules from memory.
- It loaded only the reference files it needed (the skill is built for progressive disclosure).
