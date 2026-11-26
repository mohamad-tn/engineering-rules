# Any kind of project

The rules are about delivery, not about what you build. Pick the row closest to your project.

| You are building | Profile | Stack gates you will use | Also useful |
|---|---|---|---|
| A SaaS or web app | standard | Next.js / React / Laravel / Django / Rails / .NET | bundle scan, migrations check |
| An online shop or marketplace | standard or strict | as above | the optional [domain module](../skills/engineering-rules/references/domain-optional.md) if you have location, regions or two-sided matching |
| A mobile app | standard | React Native, Expo, Flutter | keystore and cleartext checks, on-demand test builds |
| A REST or GraphQL API | standard | .NET, Node, Go, Java, Python, Rust, PHP | `audit`, schema or migration review |
| A library, SDK or CLI | strict | the language's engine | lockfile policy, `audit`, semantic versions |
| An internal tool or a script collection | lite | whatever you use | secret scan, tests |
| A content or marketing site | lite | Node (static site generators) | docs-check, link check |
| A game server or realtime backend | standard | Go, Rust, .NET, Node | continuity plan, load tests (yours) |
| A data or ML project | standard | Python | pinned requirements, `pip-audit`, notebooks excluded with `STACK_EXCLUDE` |
| Infrastructure as code, container images | `standard` | Terraform and OpenTofu, Docker | `tflint`, `trivy`, hadolint rules |
| A monorepo of several of the above | per project | all detected | one `AGENTS.md` for the whole repository |

## What does not depend on your idea

Small pull requests, secrets out of git, configuration as data, docs with code, expiring feature flags,
pinned dependencies, honest status, humans merge.

## What does depend on it

Add rules for your own domain as a numbered section of `AGENTS.md` (for example payments, health data,
children's data). Each new rule gets a row in `docs/rules-compliance.md` with an honest status, and an ADR.
