# Evals

Two small, human-run checks for the skill itself (the scripts have automated tests in `tests/`).

1. **Triggering.** Paste each prompt of `trigger-prompts.json` into an agent that has the skill installed.
   The skill should activate for `should_trigger` prompts and stay quiet for `should_not_trigger` ones.
   Aim for at least 11 of 12 and 7 of 7. If it misses, improve the `description` in `SKILL.md`
   (what it does and when to use it, in the words people actually use) and run the prompts again.
2. **Behaviour.** Run the scenarios in `scenarios.md` and note pass or fail per scenario.

These are not run in CI because they need a language model. If you have an evaluation harness, `trigger-prompts.json` is plain data.
