# Context budget

An AI agent has a limited context window, and some of what it loads is paid for in every session. This skill is
built so the agent receives **every** binding rule without filling that window.

## What is loaded, and when

| Layer | Size (estimated) | Loaded |
|---|---|---|
| Skill name and description | about 250 tokens | always, for every installed skill |
| `SKILL.md` | about 1.6k tokens (80 lines) | when the skill triggers |
| `AGENTS.md` in an adopting repository | about 1.5k tokens (90 lines) | every session in that repository |
| Bridge files (`CLAUDE.md`, Cursor rule, Copilot, Gemini, Windsurf) | under 150 tokens each | every session, per tool |
| One reference file | at most 2.6k tokens | only when the task needs it |
| `llms-full.txt` | about 7.7k tokens | for tools that fetch one URL |

Token counts are estimates (about 3.6 characters per token in English, about 2 per Arabic letter), so the Arabic edition costs
roughly twice as much per word.

## Design rules

- **The complete binding rule set is one short file** (`templates/AGENTS.md`). Every rule an agent must obey is stated there; details live in references.
- **`SKILL.md` is a router**: the six-line core, what to do for each kind of request, the hard rules, and where everything is.
- **Progressive disclosure**: references are separate files, one topic each, so loading one never drags in the others.
- **No rule only in a deep file.** A rule that is only in a reference can be missed. The test below enforces this.

## Enforced by a test

`tests/test-context.sh` fails when:

- `SKILL.md` or `AGENTS.md` grows past its line or token budget, or a reference file does, or a bridge file does;
- a frontmatter limit of the Agent Skills specification is exceeded (name 64 characters, description 1024, compatibility 500);
- a binding rule listed in `tests/rule-coverage.json` is not stated in `AGENTS.md`, in English and in Arabic;
- a new universal rule appears in the rule index without a coverage entry.

## For agents with small windows

Read `AGENTS.md` first (it is complete), then only the one reference the task needs. `llms-full.txt` holds the essentials in a single file.
